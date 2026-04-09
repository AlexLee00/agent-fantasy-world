// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract OracleGateway is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    uint8 public constant CONSENSUS_THRESHOLD = 67;
    uint256 public constant SUBMISSION_WINDOW = 30;

    struct PendingAction {
        uint256 agentId;
        uint256 submittedBlock;
        uint8 totalSubmissions;
        uint8 consensusCount;
        bytes32 winningHash;
        bool executed;
    }

    mapping(uint256 => PendingAction) public pending;
    mapping(uint256 => mapping(address => bytes32)) public nodeSubmission;
    mapping(uint256 => mapping(bytes32 => uint8)) public hashVotes;
    mapping(bytes32 => bytes) public resultData;

    uint256 public totalNodes;
    mapping(address => bool) public registeredNodes;

    address public agentRegistry;
    address public questEngine;
    address public nodeRegistry;

    event ResultSubmitted(uint256 indexed agentId, address indexed node, bytes32 resultHash);
    event ConsensusReached(uint256 indexed agentId, bytes32 resultHash);
    event TimeoutHandled(uint256 indexed agentId, bool executed);
    event NodeRegistered(address indexed node);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address _agentRegistry) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        agentRegistry = _agentRegistry;
    }

    modifier onlyNode() {
        require(registeredNodes[msg.sender], "OracleGateway: not registered node");
        _;
    }

    function submitResult(
        uint256 agentId,
        bytes32 resultHash,
        bytes calldata encodedResult
    ) external onlyNode {
        require(nodeSubmission[agentId][msg.sender] == bytes32(0), "OracleGateway: already submitted");

        PendingAction storage action = pending[agentId];
        if (action.submittedBlock == 0) {
            action.agentId = agentId;
            action.submittedBlock = block.number;
        }

        require(!action.executed, "OracleGateway: already executed");

        nodeSubmission[agentId][msg.sender] = resultHash;
        resultData[resultHash] = encodedResult;
        hashVotes[agentId][resultHash]++;
        action.totalSubmissions++;

        emit ResultSubmitted(agentId, msg.sender, resultHash);

        uint8 votes = hashVotes[agentId][resultHash];
        uint8 pct = totalNodes > 0 ? uint8(uint256(votes) * 100 / totalNodes) : 0;
        if (pct >= CONSENSUS_THRESHOLD) {
            action.winningHash = resultHash;
            action.consensusCount = votes;
            _executeResult(agentId, resultHash);
        }
    }

    function handleTimeout(uint256 agentId) external {
        PendingAction storage action = pending[agentId];
        require(!action.executed, "OracleGateway: already executed");
        require(block.number > action.submittedBlock + SUBMISSION_WINDOW, "OracleGateway: window not expired");

        if (action.winningHash != bytes32(0)) {
            _executeResult(agentId, action.winningHash);
            emit TimeoutHandled(agentId, true);
        } else {
            action.executed = true;
            emit TimeoutHandled(agentId, false);
        }
    }

    function registerNode(address node) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!registeredNodes[node], "OracleGateway: already registered");
        registeredNodes[node] = true;
        totalNodes++;
        emit NodeRegistered(node);
    }

    function removeNode(address node) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(registeredNodes[node], "OracleGateway: not registered");
        registeredNodes[node] = false;
        if (totalNodes > 0) totalNodes--;
    }

    function setAgentRegistry(address addr) external onlyRole(DEFAULT_ADMIN_ROLE) {
        agentRegistry = addr;
    }

    function setQuestEngine(address addr) external onlyRole(DEFAULT_ADMIN_ROLE) {
        questEngine = addr;
    }

    function setNodeRegistry(address addr) external onlyRole(DEFAULT_ADMIN_ROLE) {
        nodeRegistry = addr;
    }

    function _executeResult(uint256 agentId, bytes32 resultHash) internal {
        pending[agentId].executed = true;
        emit ConsensusReached(agentId, resultHash);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
