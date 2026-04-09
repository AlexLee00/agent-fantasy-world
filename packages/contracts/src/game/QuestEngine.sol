// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IQuestEconomyEngine {
    function mintForQuest(address to, uint256 amount, uint256 questId) external;
}

interface IQuestAgentRegistry {
    function getObserver(uint256 agentId) external view returns (address);
}

/**
 * @title QuestEngine — quest creation, progress, and completion
 * @notice Community quest rewards split 95% to the agent observer and 5% to the creator.
 */
contract QuestEngine is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant CURATOR_ROLE = keccak256("CURATOR_ROLE");

    uint256 public constant CREATOR_ROYALTY_BPS = 500;

    enum QuestType { KILL, COLLECT, EXPLORE, DELIVER, ESCORT }
    enum QuestDifficulty { F, E, D, C, B, A, S }
    enum QuestStatus { AVAILABLE, IN_PROGRESS, COMPLETED, FAILED, EXPIRED }

    struct QuestReward {
        uint256 soulAmount;
        uint256 expAmount;
        uint256 afwAmount;
        uint256[] itemIds;
    }

    struct QuestCondition {
        QuestType questType;
        uint256 targetId;
        uint32 targetCount;
        uint256 timeLimitSec;
    }

    struct Quest {
        uint256 questId;
        string name;
        string description;
        uint256 zoneId;
        QuestDifficulty difficulty;
        QuestCondition condition;
        QuestReward reward;
        address creator;
        uint256 creatorRoyaltyBps;
        bool isActive;
        uint256 createdAt;
    }

    struct AgentProgress {
        uint256 questId;
        uint256 agentId;
        QuestStatus status;
        uint32 currentCount;
        uint256 startedAt;
        uint256 deadline;
    }

    mapping(uint256 => Quest) public quests;
    mapping(uint256 => AgentProgress) public agentProgress;
    mapping(uint256 => uint256[]) public zoneQuests;
    mapping(address => uint256) public creatorEarned;

    uint256 public totalQuests;
    uint256 public communityQuestStakeSoul;

    address public economyEngine;
    address public agentRegistry;

    event QuestRegistered(uint256 indexed questId, address indexed creator, string name);
    event QuestStarted(uint256 indexed questId, uint256 indexed agentId);
    event QuestCompleted(uint256 indexed questId, uint256 indexed agentId, address creator);
    event QuestFailed(uint256 indexed questId, uint256 indexed agentId);
    event RoyaltyPaid(address indexed creator, uint256 soulAmount, uint256 questId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address _agentRegistry, address _economyEngine) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        agentRegistry = _agentRegistry;
        economyEngine = _economyEngine;
        communityQuestStakeSoul = 50 * 10 ** 18;
    }

    function registerQuest(
        string calldata name,
        string calldata description,
        uint256 zoneId,
        QuestDifficulty difficulty,
        QuestCondition calldata condition,
        QuestReward calldata reward
    ) external returns (uint256 questId) {
        questId = ++totalQuests;

        quests[questId] = Quest({
            questId: questId,
            name: name,
            description: description,
            zoneId: zoneId,
            difficulty: difficulty,
            condition: condition,
            reward: reward,
            creator: msg.sender,
            creatorRoyaltyBps: CREATOR_ROYALTY_BPS,
            isActive: true,
            createdAt: block.timestamp
        });

        zoneQuests[zoneId].push(questId);
        emit QuestRegistered(questId, msg.sender, name);
    }

    function startQuest(uint256 agentId, uint256 questId) external onlyRole(ORACLE_ROLE) {
        Quest storage quest = quests[questId];
        require(quest.isActive, "QuestEngine: quest inactive");

        uint256 deadline = quest.condition.timeLimitSec > 0 ? block.timestamp + quest.condition.timeLimitSec : 0;
        agentProgress[agentId] = AgentProgress({
            questId: questId,
            agentId: agentId,
            status: QuestStatus.IN_PROGRESS,
            currentCount: 0,
            startedAt: block.timestamp,
            deadline: deadline
        });

        emit QuestStarted(questId, agentId);
    }

    function updateProgress(uint256 agentId, uint32 newCount, bool failed) external onlyRole(ORACLE_ROLE) {
        AgentProgress storage progress = agentProgress[agentId];
        require(progress.status == QuestStatus.IN_PROGRESS, "QuestEngine: not in progress");

        if (progress.deadline > 0 && block.timestamp > progress.deadline) {
            progress.status = QuestStatus.EXPIRED;
            emit QuestFailed(progress.questId, agentId);
            return;
        }

        if (failed) {
            progress.status = QuestStatus.FAILED;
            emit QuestFailed(progress.questId, agentId);
            return;
        }

        progress.currentCount = newCount;
        Quest storage quest = quests[progress.questId];
        if (newCount >= quest.condition.targetCount) {
            _completeQuest(agentId, progress.questId);
        }
    }

    function getZoneQuests(uint256 zoneId) external view returns (uint256[] memory) {
        return zoneQuests[zoneId];
    }

    function getAgentProgress(uint256 agentId) external view returns (AgentProgress memory) {
        return agentProgress[agentId];
    }

    function deactivateQuest(uint256 questId) external onlyRole(CURATOR_ROLE) {
        quests[questId].isActive = false;
    }

    function setEconomyEngine(address addr) external onlyRole(DEFAULT_ADMIN_ROLE) {
        economyEngine = addr;
    }

    function _completeQuest(uint256 agentId, uint256 questId) internal {
        AgentProgress storage progress = agentProgress[agentId];
        Quest storage quest = quests[questId];
        progress.status = QuestStatus.COMPLETED;

        address observer = IQuestAgentRegistry(agentRegistry).getObserver(agentId);
        uint256 royalty = quest.reward.soulAmount * CREATOR_ROYALTY_BPS / 10000;
        uint256 agentReward = quest.reward.soulAmount - royalty;

        if (agentReward > 0) {
            IQuestEconomyEngine(economyEngine).mintForQuest(observer, agentReward, questId);
        }

        if (royalty > 0) {
            creatorEarned[quest.creator] += royalty;
            IQuestEconomyEngine(economyEngine).mintForQuest(quest.creator, royalty, questId);
            emit RoyaltyPaid(quest.creator, royalty, questId);
        }

        emit QuestCompleted(questId, agentId, quest.creator);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
