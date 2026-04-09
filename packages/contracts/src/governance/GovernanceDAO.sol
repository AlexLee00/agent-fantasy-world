// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract GovernanceDAO is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant ARCHITECT_ROLE = keccak256("ARCHITECT_ROLE");

    enum ProposalType { PARAMETER_CHANGE, CONTRACT_UPGRADE, ZONE_UNLOCK, GRANT, EMERGENCY }
    enum ProposalState { PENDING, ACTIVE, SUCCEEDED, DEFEATED, EXECUTED, CANCELLED }

    struct Proposal {
        uint256 proposalId;
        address proposer;
        ProposalType proposalType;
        string title;
        string description;
        bytes callData;
        address targetContract;
        uint256 createdAt;
        uint256 voteStartAt;
        uint256 voteEndAt;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        ProposalState state;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(address => bool) public frozenWallets;

    uint256 public totalProposals;
    uint256 public constant DISCUSSION_PERIOD = 7 days;
    uint256 public constant VOTING_PERIOD = 3 days;
    uint256 public constant TIMELOCK_PERIOD = 2 days;
    uint256 public constant QUORUM_BPS = 400;
    uint256 public constant PROPOSAL_THRESHOLD = 10_000 * 10 ** 18;

    uint256 public constant BASE_WEIGHT = 100;
    uint256 public constant NODE_WEIGHT = 150;
    uint256 public constant ARCHITECT_WEIGHT = 200;

    address public afwToken;
    address public nodeRegistry;

    event ProposalCreated(uint256 indexed id, address indexed proposer, string title, ProposalType proposalType);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint8 support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event WalletFrozen(address indexed wallet);
    event WalletUnfrozen(address indexed wallet);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address _afwToken, address _nodeRegistry) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        afwToken = _afwToken;
        nodeRegistry = _nodeRegistry;
    }

    function propose(
        ProposalType proposalType,
        string calldata title,
        string calldata description,
        address target,
        bytes calldata callData
    ) external returns (uint256 proposalId) {
        proposalId = ++totalProposals;
        proposals[proposalId] = Proposal({
            proposalId: proposalId,
            proposer: msg.sender,
            proposalType: proposalType,
            title: title,
            description: description,
            callData: callData,
            targetContract: target,
            createdAt: block.timestamp,
            voteStartAt: block.timestamp + DISCUSSION_PERIOD,
            voteEndAt: block.timestamp + DISCUSSION_PERIOD + VOTING_PERIOD,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            state: ProposalState.PENDING
        });

        emit ProposalCreated(proposalId, msg.sender, title, proposalType);
    }

    function castVote(uint256 proposalId, uint8 support) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.voteStartAt, "GovernanceDAO: voting not started");
        require(block.timestamp <= proposal.voteEndAt, "GovernanceDAO: voting ended");
        require(!hasVoted[proposalId][msg.sender], "GovernanceDAO: already voted");

        hasVoted[proposalId][msg.sender] = true;
        uint256 weight = _calculateWeight(msg.sender);

        if (support == 1) proposal.forVotes += weight;
        else if (support == 0) proposal.againstVotes += weight;
        else proposal.abstainVotes += weight;

        if (proposal.state == ProposalState.PENDING) {
            proposal.state = ProposalState.ACTIVE;
        }

        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    function finalize(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.voteEndAt, "GovernanceDAO: voting ongoing");
        require(proposal.state == ProposalState.ACTIVE, "GovernanceDAO: not active");

        if (proposal.forVotes > proposal.againstVotes) proposal.state = ProposalState.SUCCEEDED;
        else proposal.state = ProposalState.DEFEATED;
    }

    function execute(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.SUCCEEDED, "GovernanceDAO: not succeeded");
        require(block.timestamp >= proposal.voteEndAt + TIMELOCK_PERIOD, "GovernanceDAO: timelock");

        proposal.state = ProposalState.EXECUTED;
        (bool ok,) = proposal.targetContract.call(proposal.callData);
        require(ok, "GovernanceDAO: execution failed");
        emit ProposalExecuted(proposalId);
    }

    function freezeWallet(address wallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        frozenWallets[wallet] = true;
        emit WalletFrozen(wallet);
    }

    function unfreezeWallet(address wallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        frozenWallets[wallet] = false;
        emit WalletUnfrozen(wallet);
    }

    function isWalletFrozen(address wallet) external view returns (bool) {
        return frozenWallets[wallet];
    }

    function getProposal(uint256 id) external view returns (Proposal memory) {
        return proposals[id];
    }

    function _calculateWeight(address voter) internal view returns (uint256) {
        uint256 balance = 1000 * 10 ** 18;
        uint256 mult = BASE_WEIGHT;
        if (hasRole(ARCHITECT_ROLE, voter)) mult = ARCHITECT_WEIGHT;
        return balance * mult / 100;
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
