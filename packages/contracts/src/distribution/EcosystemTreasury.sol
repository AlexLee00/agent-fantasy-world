// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EcosystemTreasury is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    struct Proposal {
        uint256 proposalId;
        address proposer;
        address recipient;
        uint256 amount;
        string description;
        uint256 yesVotes;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    uint256 public totalProposals;
    uint256 public executionThreshold;
    address public afwToken;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, address indexed recipient, uint256 amount);
    event ProposalVoted(uint256 indexed proposalId, address indexed voter, uint256 yesVotes);
    event ProposalExecuted(uint256 indexed proposalId, address indexed recipient, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address _afwToken, uint256 _executionThreshold) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        afwToken = _afwToken;
        executionThreshold = _executionThreshold == 0 ? 1 : _executionThreshold;
    }

    function proposeSpend(address recipient, uint256 amount, string calldata description)
        external
        returns (uint256 proposalId)
    {
        require(recipient != address(0), "EcosystemTreasury: recipient required");
        require(amount > 0, "EcosystemTreasury: amount required");

        proposalId = ++totalProposals;
        proposals[proposalId] = Proposal({
            proposalId: proposalId,
            proposer: msg.sender,
            recipient: recipient,
            amount: amount,
            description: description,
            yesVotes: 0,
            executed: false
        });

        emit ProposalCreated(proposalId, msg.sender, recipient, amount);
    }

    function voteOnProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.proposalId != 0, "EcosystemTreasury: proposal not found");
        require(!proposal.executed, "EcosystemTreasury: already executed");
        require(!hasVoted[proposalId][msg.sender], "EcosystemTreasury: already voted");

        hasVoted[proposalId][msg.sender] = true;
        proposal.yesVotes += 1;

        emit ProposalVoted(proposalId, msg.sender, proposal.yesVotes);
    }

    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.proposalId != 0, "EcosystemTreasury: proposal not found");
        require(!proposal.executed, "EcosystemTreasury: already executed");
        require(proposal.yesVotes >= executionThreshold, "EcosystemTreasury: threshold not met");

        proposal.executed = true;
        IERC20(afwToken).transfer(proposal.recipient, proposal.amount);

        emit ProposalExecuted(proposalId, proposal.recipient, proposal.amount);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
