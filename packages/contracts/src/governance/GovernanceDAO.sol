// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title GovernanceDAO — AIP 제안/투표/타임락 실행
 * @notice AFW Improvement Proposal 시스템
 *
 * 투표 가중치:
 *   일반 $AFW 홀더   → 1.0x
 *   노드 제공자      → 1.5x
 *   Architect+ 기여자 → 2.0x
 *
 * 프로세스:
 *   제안(7일 토론) → 투표(3일) → 타임락(48시간) → 실행
 */
contract GovernanceDAO is AccessControl {
    bytes32 public constant ARCHITECT_ROLE = keccak256("ARCHITECT_ROLE");

    enum ProposalType  { PARAMETER_CHANGE, CONTRACT_UPGRADE, ZONE_UNLOCK, GRANT, EMERGENCY }
    enum ProposalState { PENDING, ACTIVE, SUCCEEDED, DEFEATED, EXECUTED, CANCELLED }

    struct Proposal {
        uint256       proposalId;
        address       proposer;
        ProposalType  proposalType;
        string        title;
        string        description;
        bytes         callData;
        address       targetContract;
        uint256       createdAt;
        uint256       voteStartAt;
        uint256       voteEndAt;
        uint256       forVotes;
        uint256       againstVotes;
        uint256       abstainVotes;
        ProposalState state;
    }

    mapping(uint256 => Proposal)              public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    uint256 public totalProposals;
    uint256 public constant DISCUSSION_PERIOD = 7 days;
    uint256 public constant VOTING_PERIOD     = 3 days;
    uint256 public constant TIMELOCK_PERIOD   = 2 days;
    uint256 public constant QUORUM_BPS        = 400;  // 4% 쿼럼
    uint256 public constant PROPOSAL_THRESHOLD = 10_000 * 10**18; // 제안 최소 보유량

    // 투표 배율 (100 = 1.0x)
    uint256 public constant BASE_WEIGHT      = 100;
    uint256 public constant NODE_WEIGHT      = 150;
    uint256 public constant ARCHITECT_WEIGHT = 200;

    address public afwToken;
    address public nodeRegistry;

    event ProposalCreated(uint256 indexed id, address indexed proposer, string title, ProposalType proposalType);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint8 support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    constructor(address _afwToken, address _nodeRegistry) {
        afwToken      = _afwToken;
        nodeRegistry  = _nodeRegistry;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // ─── 제안 생성 ───────────────────────────────────────────────
    function propose(
        ProposalType    _type,
        string calldata _title,
        string calldata _desc,
        address         _target,
        bytes calldata  _callData
    ) external returns (uint256 proposalId) {
        // TODO: AFWToken 잔액 체크 >= PROPOSAL_THRESHOLD
        proposalId = ++totalProposals;

        proposals[proposalId] = Proposal({
            proposalId:      proposalId,
            proposer:        msg.sender,
            proposalType:    _type,
            title:           _title,
            description:     _desc,
            callData:        _callData,
            targetContract:  _target,
            createdAt:       block.timestamp,
            voteStartAt:     block.timestamp + DISCUSSION_PERIOD,
            voteEndAt:       block.timestamp + DISCUSSION_PERIOD + VOTING_PERIOD,
            forVotes:        0,
            againstVotes:    0,
            abstainVotes:    0,
            state:           ProposalState.PENDING
        });
        emit ProposalCreated(proposalId, msg.sender, _title, _type);
    }

    // ─── 투표 (0=반대, 1=찬성, 2=기권) ─────────────────────────
    function castVote(uint256 _proposalId, uint8 _support) external {
        Proposal storage p = proposals[_proposalId];
        require(block.timestamp >= p.voteStartAt, "GovernanceDAO: voting not started");
        require(block.timestamp <= p.voteEndAt,   "GovernanceDAO: voting ended");
        require(!hasVoted[_proposalId][msg.sender], "GovernanceDAO: already voted");

        hasVoted[_proposalId][msg.sender] = true;
        uint256 weight = _calculateWeight(msg.sender);

        if      (_support == 1) p.forVotes     += weight;
        else if (_support == 0) p.againstVotes += weight;
        else                    p.abstainVotes += weight;

        if (p.state == ProposalState.PENDING) p.state = ProposalState.ACTIVE;
        emit VoteCast(_proposalId, msg.sender, _support, weight);
    }

    // ─── 결과 확정 ─────────────────────────────────────────────
    function finalize(uint256 _proposalId) external {
        Proposal storage p = proposals[_proposalId];
        require(block.timestamp > p.voteEndAt, "GovernanceDAO: voting ongoing");
        require(p.state == ProposalState.ACTIVE, "GovernanceDAO: not active");

        if (p.forVotes > p.againstVotes) {
            p.state = ProposalState.SUCCEEDED;
        } else {
            p.state = ProposalState.DEFEATED;
        }
    }

    // ─── 실행 (타임락 후) ──────────────────────────────────────
    function execute(uint256 _proposalId) external {
        Proposal storage p = proposals[_proposalId];
        require(p.state == ProposalState.SUCCEEDED, "GovernanceDAO: not succeeded");
        require(block.timestamp >= p.voteEndAt + TIMELOCK_PERIOD, "GovernanceDAO: timelock");

        p.state = ProposalState.EXECUTED;
        (bool ok,) = p.targetContract.call(p.callData);
        require(ok, "GovernanceDAO: execution failed");
        emit ProposalExecuted(_proposalId);
    }

    function _calculateWeight(address _voter) internal view returns (uint256) {
        // TODO: AFWToken.balanceOf(_voter) 연동
        uint256 balance = 1000 * 10**18; // 임시
        uint256 mult    = BASE_WEIGHT;
        // TODO: nodeRegistry.isActive(_voter) 체크 → NODE_WEIGHT
        if (hasRole(ARCHITECT_ROLE, _voter)) mult = ARCHITECT_WEIGHT;
        return balance * mult / 100;
    }

    function getProposal(uint256 _id) external view returns (Proposal memory) {
        return proposals[_id];
    }
}
