// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title AgentRegistry — 에이전트 생성 및 상태 관리
 * @notice AFW 세계의 모든 에이전트가 등록되는 핵심 컨트랙트
 *
 * 에이전트 생명주기:
 *   생성 → 탐험 → 성장 → 마일스톤 → 유저 개입 or 자율결정
 */
contract AgentRegistry is AccessControl {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    enum AgentClass  { WARRIOR, MAGE, RANGER, HEALER, TANK }
    enum AgentStatus { ALIVE, DEAD, RESTING, IN_COMBAT, TRAVELING }

    struct Personality {
        uint8 bravery;      // 용감함 0-100
        uint8 greed;        // 탐욕  0-100
        uint8 sociability;  // 사교성 0-100
        uint8 curiosity;    // 호기심 0-100
        uint8 loyalty;      // 충성심 0-100
    }

    struct Stats {
        uint32 hp;     uint32 maxHp;
        uint32 mp;     uint32 maxMp;
        uint32 attack; uint32 defense; uint32 speed;
    }

    struct Agent {
        uint256  agentId;
        address  observer;       // 연결 유저 (없으면 address(0))
        AgentClass  agentClass;
        AgentStatus status;
        uint8    level;
        uint64   experience;
        uint256  zoneId;
        Personality personality;
        Stats    stats;
        uint256  createdAt;
        uint256  lastActionBlock;
        bytes32  personalityHash; // LLM 프롬프트 시드
    }

    mapping(uint256 => Agent)    public agents;
    mapping(address => uint256[]) public observerAgents;
    mapping(uint256 => uint256[]) public zoneAgents;

    uint256 public totalAgents;
    uint256 public agentCreationCostSOUL = 100 * 10 ** 18; // 100 SOUL

    event AgentCreated(uint256 indexed agentId, address indexed observer, AgentClass agentClass);
    event AgentLevelUp(uint256 indexed agentId, uint8 newLevel);
    event AgentStatusChanged(uint256 indexed agentId, AgentStatus newStatus);
    event MilestoneTriggered(uint256 indexed agentId, string milestoneType, bytes data);
    event AgentDied(uint256 indexed agentId, string cause);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyOracle() {
        require(hasRole(ORACLE_ROLE, msg.sender), "AgentRegistry: not oracle");
        _;
    }

    modifier onlyObserver(uint256 agentId) {
        require(agents[agentId].observer == msg.sender, "AgentRegistry: not observer");
        _;
    }

    /// @notice 에이전트 생성
    function createAgent(
        AgentClass _class,
        uint8[5] calldata _personality  // [bravery, greed, sociability, curiosity, loyalty]
    ) external returns (uint256 agentId) {
        // TODO: SOUL 비용 차감
        agentId = ++totalAgents;

        bytes32 pHash = keccak256(abi.encodePacked(agentId, block.timestamp, msg.sender, _personality));

        agents[agentId] = Agent({
            agentId:         agentId,
            observer:        msg.sender,
            agentClass:      _class,
            status:          AgentStatus.ALIVE,
            level:           1,
            experience:      0,
            zoneId:          1,  // Lumenveil (마을) 시작
            personality:     Personality(_personality[0], _personality[1], _personality[2], _personality[3], _personality[4]),
            stats:           _initStats(_class),
            createdAt:       block.timestamp,
            lastActionBlock: block.number,
            personalityHash: pHash
        });

        observerAgents[msg.sender].push(agentId);
        zoneAgents[1].push(agentId);

        emit AgentCreated(agentId, msg.sender, _class);
    }

    /// @notice 오라클이 에이전트 상태 업데이트
    function updateAgentState(
        uint256 _agentId,
        Stats calldata _newStats,
        uint32 _expGained,
        uint256 _newZoneId,
        AgentStatus _newStatus
    ) external onlyOracle {
        Agent storage agent = agents[_agentId];
        agent.stats  = _newStats;
        agent.status = _newStatus;
        agent.lastActionBlock = block.number;

        if (_newZoneId != agent.zoneId) {
            agent.zoneId = _newZoneId;
        }

        agent.experience += _expGained;
        _checkLevelUp(_agentId);
        _checkMilestone(_agentId, _newStats);
    }

    /// @notice 유저 개입: 아이템 지원 (마일스톤 응답)
    function supportAgent(uint256 _agentId, uint256 _itemId) external onlyObserver(_agentId) {
        // TODO: ItemRegistry에서 아이템 이동
        emit MilestoneTriggered(_agentId, "ITEM_SUPPORT", abi.encode(_itemId));
    }

    /// @notice 마일스톤 결정 제출
    function resolveMillestone(
        uint256 _agentId,
        bytes calldata _decision,
        uint256 _milestoneId
    ) external onlyObserver(_agentId) {
        emit MilestoneTriggered(_agentId, "DECISION", abi.encode(_milestoneId, _decision));
    }

    function _checkLevelUp(uint256 _agentId) internal {
        Agent storage agent = agents[_agentId];
        uint64 needed = uint64(agent.level) * 100;
        if (agent.experience >= needed && agent.level < 99) {
            agent.level++;
            agent.experience -= needed;
            emit AgentLevelUp(_agentId, agent.level);
            emit MilestoneTriggered(_agentId, "LEVEL_UP", abi.encode(agent.level));
        }
    }

    function _checkMilestone(uint256 _agentId, Stats memory s) internal {
        if (s.maxHp > 0 && s.hp * 100 / s.maxHp <= 20) {
            emit MilestoneTriggered(_agentId, "HP_CRITICAL", abi.encode(s.hp, s.maxHp));
        }
    }

    function _initStats(AgentClass _class) internal pure returns (Stats memory s) {
        if (_class == AgentClass.WARRIOR) return Stats(100,100,50,50,20,15,10);
        if (_class == AgentClass.MAGE)    return Stats( 70, 70,120,120,25, 8,12);
        if (_class == AgentClass.RANGER)  return Stats( 80, 80,60,60,18,12,16);
        if (_class == AgentClass.HEALER)  return Stats( 75, 75,100,100,10,10,11);
        if (_class == AgentClass.TANK)    return Stats(150,150,30,30,12,25, 7);
        return Stats(100,100,50,50,15,15,10);
    }

    function getAgent(uint256 _agentId) external view returns (Agent memory) {
        return agents[_agentId];
    }

    function getObserverAgents(address _observer) external view returns (uint256[] memory) {
        return observerAgents[_observer];
    }
}
