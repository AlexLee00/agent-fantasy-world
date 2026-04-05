// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title QuestEngine — 퀘스트 생성/진행/완료 처리
 * @notice 커뮤니티 퀘스트 등록 시 완료 보상의 5%가 영구 로열티로 지급
 */
contract QuestEngine is AccessControl {
    bytes32 public constant ORACLE_ROLE   = keccak256("ORACLE_ROLE");
    bytes32 public constant CURATOR_ROLE  = keccak256("CURATOR_ROLE"); // 퀘스트 검수

    enum QuestType       { KILL, COLLECT, EXPLORE, DELIVER, ESCORT }
    enum QuestDifficulty { F, E, D, C, B, A, S }
    enum QuestStatus     { AVAILABLE, IN_PROGRESS, COMPLETED, FAILED, EXPIRED }

    struct QuestReward {
        uint256 soulAmount;
        uint256 expAmount;
        uint256 afwAmount;   // 특별 퀘스트만 (보통 0)
        uint256[] itemIds;
    }

    struct QuestCondition {
        QuestType  questType;
        uint256    targetId;     // 몬스터ID / 아이템ID / ZoneID
        uint32     targetCount;
        uint256    timeLimitSec; // 0 = 무제한
    }

    struct Quest {
        uint256        questId;
        string         name;
        string         description;
        uint256        zoneId;
        QuestDifficulty difficulty;
        QuestCondition condition;
        QuestReward    reward;
        address        creator;        // 커뮤니티 제작자
        uint256        creatorRoyaltyBps; // 500 = 5%
        bool           isActive;
        uint256        createdAt;
    }

    struct AgentProgress {
        uint256     questId;
        uint256     agentId;
        QuestStatus status;
        uint32      currentCount;
        uint256     startedAt;
        uint256     deadline;
    }

    // ─── 상태 변수 ─────────────────────────────────────────────────
    mapping(uint256 => Quest)          public quests;
    mapping(uint256 => AgentProgress)  public agentProgress; // agentId → progress
    mapping(uint256 => uint256[])      public zoneQuests;    // zoneId  → questIds[]
    mapping(address => uint256)        public creatorEarned; // 로열티 누적

    uint256 public totalQuests;
    uint256 public communityQuestStakeSoul = 50 * 10**18; // 스팸 방지 스테이킹

    address public economyEngine;
    address public agentRegistry;

    event QuestRegistered(uint256 indexed questId, address indexed creator, string name);
    event QuestStarted(uint256 indexed questId, uint256 indexed agentId);
    event QuestCompleted(uint256 indexed questId, uint256 indexed agentId, address creator);
    event QuestFailed(uint256 indexed questId, uint256 indexed agentId);
    event RoyaltyPaid(address indexed creator, uint256 soulAmount, uint256 questId);

    constructor(address _agentRegistry, address _economyEngine) {
        agentRegistry  = _agentRegistry;
        economyEngine  = _economyEngine;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // ─── 커뮤니티 퀘스트 등록 ─────────────────────────────────────
    function registerQuest(
        string calldata _name,
        string calldata _description,
        uint256 _zoneId,
        QuestDifficulty _diff,
        QuestCondition calldata _cond,
        QuestReward calldata _reward,
        uint256 _royaltyBps  // 최대 1000 = 10%
    ) external returns (uint256 questId) {
        require(_royaltyBps <= 1000, "QuestEngine: royalty > 10%");
        // TODO: SOUL 스테이킹 차감 (communityQuestStakeSoul)

        questId = ++totalQuests;
        quests[questId] = Quest({
            questId:           questId,
            name:              _name,
            description:       _description,
            zoneId:            _zoneId,
            difficulty:        _diff,
            condition:         _cond,
            reward:            _reward,
            creator:           msg.sender,
            creatorRoyaltyBps: _royaltyBps,
            isActive:          true,
            createdAt:         block.timestamp
        });
        zoneQuests[_zoneId].push(questId);
        emit QuestRegistered(questId, msg.sender, _name);
    }

    // ─── 퀘스트 시작 (Oracle 호출) ────────────────────────────────
    function startQuest(uint256 _agentId, uint256 _questId)
        external onlyRole(ORACLE_ROLE)
    {
        Quest storage q = quests[_questId];
        require(q.isActive, "QuestEngine: quest inactive");

        uint256 deadline = q.condition.timeLimitSec > 0
            ? block.timestamp + q.condition.timeLimitSec : 0;

        agentProgress[_agentId] = AgentProgress({
            questId:      _questId,
            agentId:      _agentId,
            status:       QuestStatus.IN_PROGRESS,
            currentCount: 0,
            startedAt:    block.timestamp,
            deadline:     deadline
        });
        emit QuestStarted(_questId, _agentId);
    }

    // ─── 진행도 업데이트 (Oracle 호출) ───────────────────────────
    function updateProgress(uint256 _agentId, uint32 _newCount, bool _failed)
        external onlyRole(ORACLE_ROLE)
    {
        AgentProgress storage p = agentProgress[_agentId];
        require(p.status == QuestStatus.IN_PROGRESS, "QuestEngine: not in progress");

        // 만료 체크
        if (p.deadline > 0 && block.timestamp > p.deadline) {
            p.status = QuestStatus.EXPIRED;
            emit QuestFailed(p.questId, _agentId);
            return;
        }

        if (_failed) {
            p.status = QuestStatus.FAILED;
            emit QuestFailed(p.questId, _agentId);
            return;
        }

        p.currentCount = _newCount;
        Quest storage q = quests[p.questId];

        if (_newCount >= q.condition.targetCount) {
            _completeQuest(_agentId, p.questId);
        }
    }

    function _completeQuest(uint256 _agentId, uint256 _questId) internal {
        AgentProgress storage p = agentProgress[_agentId];
        Quest storage q = quests[_questId];

        p.status = QuestStatus.COMPLETED;

        // TODO: EconomyEngine.mintForQuest() 호출 → SOUL 보상
        // TODO: AgentRegistry 경험치 지급
        // 크리에이터 로열티 지급
        if (q.creator != address(0) && q.creatorRoyaltyBps > 0) {
            uint256 royalty = q.reward.soulAmount * q.creatorRoyaltyBps / 10000;
            creatorEarned[q.creator] += royalty;
            // TODO: 실제 SOUL 전송
            emit RoyaltyPaid(q.creator, royalty, _questId);
        }
        emit QuestCompleted(_questId, _agentId, q.creator);
    }

    // ─── 조회 ─────────────────────────────────────────────────────
    function getZoneQuests(uint256 _zoneId) external view returns (uint256[] memory) {
        return zoneQuests[_zoneId];
    }

    function getAgentProgress(uint256 _agentId) external view returns (AgentProgress memory) {
        return agentProgress[_agentId];
    }

    // ─── 관리 ─────────────────────────────────────────────────────
    function deactivateQuest(uint256 _questId) external onlyRole(CURATOR_ROLE) {
        quests[_questId].isActive = false;
    }

    function setEconomyEngine(address _addr) external onlyRole(DEFAULT_ADMIN_ROLE) {
        economyEngine = _addr;
    }
}
