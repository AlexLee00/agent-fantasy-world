// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title OracleGateway — 오프체인 AI 추론 결과를 온체인에 안전하게 기록
 * @notice 노드들이 결과 해시를 제출하고 2/3 컨센서스 달성 시 실행
 *
 * 흐름:
 *   Node → submitResult(agentId, resultHash, encodedResult)
 *   2/3 이상 일치 → _executeResult() → AgentRegistry 업데이트
 *   30블록 내 컨센서스 미달 → handleTimeout()
 */
contract OracleGateway is AccessControl {
    bytes32 public constant NODE_ROLE = keccak256("NODE_ROLE");

    uint8   public constant CONSENSUS_THRESHOLD = 67; // 2/3 이상 (%)
    uint256 public constant SUBMISSION_WINDOW   = 30; // 블록 수

    struct PendingAction {
        uint256 agentId;
        uint256 submittedBlock;
        uint8   totalSubmissions;
        uint8   consensusCount;
        bytes32 winningHash;
        bool    executed;
    }

    mapping(uint256 => PendingAction)              public pending;        // agentId → pending
    mapping(uint256 => mapping(address => bytes32)) public nodeSubmission; // agentId → node → hash
    mapping(uint256 => mapping(bytes32 => uint8))   public hashVotes;      // agentId → hash → votes
    mapping(bytes32 => bytes)                       public resultData;     // hash → encodedResult

    uint256 public totalNodes;
    mapping(address => bool) public registeredNodes;

    address public agentRegistry;
    address public questEngine;
    address public nodeRegistry;

    event ResultSubmitted(uint256 indexed agentId, address indexed node, bytes32 resultHash);
    event ConsensusReached(uint256 indexed agentId, bytes32 resultHash);
    event TimeoutHandled(uint256 indexed agentId, bool executed);
    event NodeRegistered(address indexed node);

    constructor(address _agentRegistry) {
        agentRegistry = _agentRegistry;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyNode() {
        require(registeredNodes[msg.sender], "OracleGateway: not registered node");
        _;
    }

    // ─── 노드 결과 제출 ───────────────────────────────────────────
    function submitResult(
        uint256 _agentId,
        bytes32 _resultHash,
        bytes calldata _encodedResult
    ) external onlyNode {
        require(nodeSubmission[_agentId][msg.sender] == bytes32(0),
            "OracleGateway: already submitted");

        PendingAction storage p = pending[_agentId];
        if (p.submittedBlock == 0) {
            p.agentId        = _agentId;
            p.submittedBlock = block.number;
        }
        require(!p.executed, "OracleGateway: already executed");

        nodeSubmission[_agentId][msg.sender] = _resultHash;
        resultData[_resultHash]              = _encodedResult;
        hashVotes[_agentId][_resultHash]++;
        p.totalSubmissions++;

        emit ResultSubmitted(_agentId, msg.sender, _resultHash);

        // 컨센서스 체크
        uint8 votes = hashVotes[_agentId][_resultHash];
        uint8 pct   = totalNodes > 0 ? uint8(uint256(votes) * 100 / totalNodes) : 0;

        if (pct >= CONSENSUS_THRESHOLD) {
            p.winningHash    = _resultHash;
            p.consensusCount = votes;
            _executeResult(_agentId, _resultHash);
        }
    }

    // ─── 컨센서스 달성 시 실행 ────────────────────────────────────
    function _executeResult(uint256 _agentId, bytes32 _resultHash) internal {
        PendingAction storage p = pending[_agentId];
        p.executed = true;

        bytes memory data = resultData[_resultHash];
        // TODO: AgentRegistry.updateAgentState() decode & call
        // TODO: QuestEngine.updateProgress() 호출
        // TODO: 참여 노드 보상 기록

        emit ConsensusReached(_agentId, _resultHash);
    }

    // ─── 타임아웃 처리 ────────────────────────────────────────────
    function handleTimeout(uint256 _agentId) external {
        PendingAction storage p = pending[_agentId];
        require(!p.executed, "OracleGateway: already executed");
        require(block.number > p.submittedBlock + SUBMISSION_WINDOW,
            "OracleGateway: window not expired");

        // 과반수라도 있으면 실행
        if (p.winningHash != bytes32(0)) {
            _executeResult(_agentId, p.winningHash);
            emit TimeoutHandled(_agentId, true);
        } else {
            // 컨센서스 실패 — 이전 상태 유지, 패널티
            p.executed = true;
            emit TimeoutHandled(_agentId, false);
        }
    }

    // ─── 노드 등록/제거 ─────────────────────────────────────────
    function registerNode(address _node) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!registeredNodes[_node], "OracleGateway: already registered");
        registeredNodes[_node] = true;
        totalNodes++;
        emit NodeRegistered(_node);
    }

    function removeNode(address _node) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(registeredNodes[_node], "OracleGateway: not registered");
        registeredNodes[_node] = false;
        if (totalNodes > 0) totalNodes--;
    }

    function setAgentRegistry(address _addr) external onlyRole(DEFAULT_ADMIN_ROLE) {
        agentRegistry = _addr;
    }
}
