// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title AgentRegistry — agent creation and state management
 * @notice Uses open registry-based class and status definitions instead of enums.
 */
contract AgentRegistry is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant COMBAT_ROLE = keccak256("COMBAT_ROLE");

    uint32 private constant MIN_CLASS_HP = 70;
    uint32 private constant MAX_CLASS_HP = 150;
    uint32 private constant MIN_CLASS_MP = 30;
    uint32 private constant MAX_CLASS_MP = 120;
    uint32 private constant MIN_CLASS_ATK = 10;
    uint32 private constant MAX_CLASS_ATK = 25;
    uint32 private constant MIN_CLASS_DEF = 8;
    uint32 private constant MAX_CLASS_DEF = 25;
    uint32 private constant MIN_CLASS_SPD = 7;
    uint32 private constant MAX_CLASS_SPD = 16;

    struct Personality {
        uint8 bravery;
        uint8 greed;
        uint8 sociability;
        uint8 curiosity;
        uint8 loyalty;
    }

    struct Stats {
        uint32 hp;
        uint32 maxHp;
        uint32 mp;
        uint32 maxMp;
        uint32 attack;
        uint32 defense;
        uint32 speed;
    }

    struct ClassDefinition {
        uint256 classId;
        string name;
        Stats minStats;
        Stats maxStats;
        bool exists;
    }

    struct StatusDefinition {
        uint256 statusId;
        string name;
        bool isTerminal;
        bool exists;
    }

    struct Agent {
        uint256 agentId;
        address observer;
        uint256 classId;
        uint256 statusId;
        uint8 level;
        uint64 experience;
        uint256 zoneId;
        Personality personality;
        Stats stats;
        uint256 createdAt;
        uint256 lastActionBlock;
        bytes32 personalityHash;
    }

    mapping(uint256 => Agent) public agents;
    mapping(address => uint256[]) public observerAgents;
    mapping(uint256 => uint256[]) public zoneAgents;
    mapping(uint256 => ClassDefinition) public classRegistry;
    mapping(uint256 => StatusDefinition) public statusRegistry;

    uint256 public totalAgents;
    uint256 public totalClasses;
    uint256 public totalStatuses;
    uint256 public agentCreationCostSOUL;

    event AgentCreated(uint256 indexed agentId, address indexed observer, uint256 indexed classId);
    event AgentLevelUp(uint256 indexed agentId, uint8 newLevel);
    event AgentStatusChanged(uint256 indexed agentId, uint256 indexed newStatusId);
    event MilestoneTriggered(uint256 indexed agentId, string milestoneType, bytes data);
    event AgentDied(uint256 indexed agentId, string cause);
    event ClassRegistered(uint256 indexed classId, string name);
    event StatusRegistered(uint256 indexed statusId, string name, bool isTerminal);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        agentCreationCostSOUL = 100 * 10 ** 18;
    }

    modifier onlyOracle() {
        require(
            hasRole(ORACLE_ROLE, msg.sender) || hasRole(COMBAT_ROLE, msg.sender),
            "AgentRegistry: not oracle"
        );
        _;
    }

    modifier onlyObserver(uint256 agentId) {
        require(agents[agentId].observer == msg.sender, "AgentRegistry: not observer");
        _;
    }

    function registerClass(
        string calldata name,
        Stats calldata minStats,
        Stats calldata maxStats
    ) external returns (uint256 classId) {
        _validateClassStats(minStats, maxStats);

        classId = ++totalClasses;
        classRegistry[classId] = ClassDefinition({
            classId: classId,
            name: name,
            minStats: minStats,
            maxStats: maxStats,
            exists: true
        });

        emit ClassRegistered(classId, name);
    }

    function registerStatus(string calldata name, bool isTerminal) external returns (uint256 statusId) {
        statusId = ++totalStatuses;
        statusRegistry[statusId] = StatusDefinition({
            statusId: statusId,
            name: name,
            isTerminal: isTerminal,
            exists: true
        });

        emit StatusRegistered(statusId, name, isTerminal);
    }

    function createAgent(
        uint256 classId,
        uint8[5] calldata personalityInput
    ) external returns (uint256 agentId) {
        require(classRegistry[classId].exists, "AgentRegistry: class not found");
        require(statusRegistry[1].exists, "AgentRegistry: alive status missing");

        for (uint256 i = 0; i < personalityInput.length; i++) {
            require(personalityInput[i] <= 100, "AgentRegistry: invalid personality");
        }

        agentId = ++totalAgents;
        bytes32 personalityHash = keccak256(
            abi.encodePacked(agentId, block.timestamp, block.prevrandao, msg.sender, personalityInput)
        );

        agents[agentId] = Agent({
            agentId: agentId,
            observer: msg.sender,
            classId: classId,
            statusId: 1,
            level: 1,
            experience: 0,
            zoneId: 1,
            personality: Personality(
                personalityInput[0],
                personalityInput[1],
                personalityInput[2],
                personalityInput[3],
                personalityInput[4]
            ),
            stats: _rollStats(classId, personalityHash),
            createdAt: block.timestamp,
            lastActionBlock: block.number,
            personalityHash: personalityHash
        });

        observerAgents[msg.sender].push(agentId);
        zoneAgents[1].push(agentId);

        emit AgentCreated(agentId, msg.sender, classId);
    }

    function updateAgentState(
        uint256 agentId,
        Stats calldata newStats,
        uint32 expGained,
        uint256 newZoneId,
        uint256 newStatusId
    ) external onlyOracle {
        require(statusRegistry[newStatusId].exists, "AgentRegistry: status not found");

        Agent storage agent = agents[agentId];
        require(agent.agentId != 0, "AgentRegistry: agent not found");

        agent.stats = newStats;
        agent.lastActionBlock = block.number;
        agent.experience += expGained;

        if (newZoneId != agent.zoneId) {
            agent.zoneId = newZoneId;
            zoneAgents[newZoneId].push(agentId);
        }

        if (newStatusId != agent.statusId) {
            agent.statusId = newStatusId;
            emit AgentStatusChanged(agentId, newStatusId);

            if (statusRegistry[newStatusId].isTerminal) {
                emit AgentDied(agentId, statusRegistry[newStatusId].name);
            }
        }

        _checkLevelUp(agentId);
        _checkMilestone(agentId, newStats);
    }

    function supportAgent(uint256 agentId, uint256 itemId) external onlyObserver(agentId) {
        emit MilestoneTriggered(agentId, "ITEM_SUPPORT", abi.encode(itemId));
    }

    function resolveMillestone(
        uint256 agentId,
        bytes calldata decision,
        uint256 milestoneId
    ) external onlyObserver(agentId) {
        emit MilestoneTriggered(agentId, "DECISION", abi.encode(milestoneId, decision));
    }

    function getAgent(uint256 agentId) external view returns (Agent memory) {
        return agents[agentId];
    }

    function getObserverAgents(address observer) external view returns (uint256[] memory) {
        return observerAgents[observer];
    }

    function getObserver(uint256 agentId) external view returns (address) {
        return agents[agentId].observer;
    }

    function applyCombatResult(
        uint256 agentId,
        Stats calldata newStats,
        uint64 newExperience,
        uint256 newZoneId,
        uint256 newStatusId
    ) external onlyRole(COMBAT_ROLE) {
        require(statusRegistry[newStatusId].exists, "AgentRegistry: status not found");

        Agent storage agent = agents[agentId];
        require(agent.agentId != 0, "AgentRegistry: agent not found");

        agent.stats = newStats;
        agent.lastActionBlock = block.number;
        agent.experience = newExperience;

        if (newZoneId != agent.zoneId) {
            agent.zoneId = newZoneId;
            zoneAgents[newZoneId].push(agentId);
        }

        if (newStatusId != agent.statusId) {
            agent.statusId = newStatusId;
            emit AgentStatusChanged(agentId, newStatusId);

            if (statusRegistry[newStatusId].isTerminal) {
                emit AgentDied(agentId, statusRegistry[newStatusId].name);
            }
        }

        _checkMilestone(agentId, newStats);
    }

    function _rollStats(uint256 classId, bytes32 seed) internal view returns (Stats memory) {
        ClassDefinition storage classDef = classRegistry[classId];
        return Stats({
            hp: _rollWithin(classDef.minStats.hp, classDef.maxStats.hp, seed, "hp"),
            maxHp: _rollWithin(classDef.minStats.maxHp, classDef.maxStats.maxHp, seed, "maxHp"),
            mp: _rollWithin(classDef.minStats.mp, classDef.maxStats.mp, seed, "mp"),
            maxMp: _rollWithin(classDef.minStats.maxMp, classDef.maxStats.maxMp, seed, "maxMp"),
            attack: _rollWithin(classDef.minStats.attack, classDef.maxStats.attack, seed, "attack"),
            defense: _rollWithin(classDef.minStats.defense, classDef.maxStats.defense, seed, "defense"),
            speed: _rollWithin(classDef.minStats.speed, classDef.maxStats.speed, seed, "speed")
        });
    }

    function _rollWithin(uint32 minValue, uint32 maxValue, bytes32 seed, string memory salt)
        internal
        view
        returns (uint32)
    {
        if (minValue == maxValue) {
            return minValue;
        }

        uint256 range = uint256(maxValue - minValue) + 1;
        uint256 randomValue = uint256(keccak256(abi.encodePacked(seed, salt, block.timestamp, msg.sender)));
        return uint32(uint256(minValue) + (randomValue % range));
    }

    function _checkLevelUp(uint256 agentId) internal {
        Agent storage agent = agents[agentId];
        uint64 needed = uint64(agent.level) * 100;
        if (agent.experience >= needed && agent.level < 99) {
            agent.level++;
            agent.experience -= needed;
            emit AgentLevelUp(agentId, agent.level);
            emit MilestoneTriggered(agentId, "LEVEL_UP", abi.encode(agent.level));
        }
    }

    function _checkMilestone(uint256 agentId, Stats memory s) internal {
        if (s.maxHp > 0 && s.hp * 100 / s.maxHp <= 20) {
            emit MilestoneTriggered(agentId, "HP_CRITICAL", abi.encode(s.hp, s.maxHp));
        }
    }

    function _validateClassStats(Stats calldata minStats, Stats calldata maxStats) internal pure {
        require(minStats.hp <= maxStats.hp, "AgentRegistry: invalid hp range");
        require(minStats.maxHp <= maxStats.maxHp, "AgentRegistry: invalid maxHp range");
        require(minStats.mp <= maxStats.mp, "AgentRegistry: invalid mp range");
        require(minStats.maxMp <= maxStats.maxMp, "AgentRegistry: invalid maxMp range");
        require(minStats.attack <= maxStats.attack, "AgentRegistry: invalid atk range");
        require(minStats.defense <= maxStats.defense, "AgentRegistry: invalid def range");
        require(minStats.speed <= maxStats.speed, "AgentRegistry: invalid spd range");

        _requireBetween(minStats.hp, MIN_CLASS_HP, MAX_CLASS_HP, "AgentRegistry: hp out of range");
        _requireBetween(maxStats.hp, MIN_CLASS_HP, MAX_CLASS_HP, "AgentRegistry: hp out of range");
        _requireBetween(minStats.maxHp, MIN_CLASS_HP, MAX_CLASS_HP, "AgentRegistry: maxHp out of range");
        _requireBetween(maxStats.maxHp, MIN_CLASS_HP, MAX_CLASS_HP, "AgentRegistry: maxHp out of range");
        _requireBetween(minStats.mp, MIN_CLASS_MP, MAX_CLASS_MP, "AgentRegistry: mp out of range");
        _requireBetween(maxStats.mp, MIN_CLASS_MP, MAX_CLASS_MP, "AgentRegistry: mp out of range");
        _requireBetween(minStats.maxMp, MIN_CLASS_MP, MAX_CLASS_MP, "AgentRegistry: maxMp out of range");
        _requireBetween(maxStats.maxMp, MIN_CLASS_MP, MAX_CLASS_MP, "AgentRegistry: maxMp out of range");
        _requireBetween(minStats.attack, MIN_CLASS_ATK, MAX_CLASS_ATK, "AgentRegistry: atk out of range");
        _requireBetween(maxStats.attack, MIN_CLASS_ATK, MAX_CLASS_ATK, "AgentRegistry: atk out of range");
        _requireBetween(minStats.defense, MIN_CLASS_DEF, MAX_CLASS_DEF, "AgentRegistry: def out of range");
        _requireBetween(maxStats.defense, MIN_CLASS_DEF, MAX_CLASS_DEF, "AgentRegistry: def out of range");
        _requireBetween(minStats.speed, MIN_CLASS_SPD, MAX_CLASS_SPD, "AgentRegistry: spd out of range");
        _requireBetween(maxStats.speed, MIN_CLASS_SPD, MAX_CLASS_SPD, "AgentRegistry: spd out of range");
    }

    function _requireBetween(uint32 value, uint32 minValue, uint32 maxValue, string memory reason) internal pure {
        require(value >= minValue && value <= maxValue, reason);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
