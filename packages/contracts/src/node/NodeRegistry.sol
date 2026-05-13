// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract NodeRegistry is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant SLASHER_ROLE = keccak256("SLASHER_ROLE");

    enum NodeTier { SEED, GROWTH, ELDER }

    struct NodeSpec {
        uint8 cpuCores;
        uint32 ramGB;
        uint32 gpuVramGB;
        uint32 bandwidthMbps;
    }

    struct NodeInfo {
        address operator;
        NodeTier tier;
        NodeSpec spec;
        uint256 stakedAFW;
        uint256 registeredAt;
        uint256 totalUptimeBlocks;
        uint256 pendingReward;
        uint256 totalSlashings;
        bool isActive;
        string endpoint;
    }

    mapping(address => NodeInfo) public nodes;
    address[] public activeNodes;

    uint256 public constant SEED_STAKE = 1_000 * 10 ** 18;
    uint256 public constant GROWTH_STAKE = 5_000 * 10 ** 18;
    uint256 public constant ELDER_STAKE = 20_000 * 10 ** 18;

    uint256 public constant SEED_MULT = 100;
    uint256 public constant GROWTH_MULT = 250;
    uint256 public constant ELDER_MULT = 600;

    uint256 public constant UPTIME_BONUS_MULT = 120;
    uint256 public constant UPTIME_BONUS_THRESHOLD = 99;

    uint256 public baseBlockReward;
    address public afwToken;
    address public worldMap;

    event NodeRegistered(address indexed operator, NodeTier tier, string endpoint);
    event NodeDeactivated(address indexed operator);
    event NodeEndpointUpdated(address indexed operator, string endpoint);
    event RewardClaimed(address indexed operator, uint256 amount);
    event NodeSlashed(address indexed operator, uint256 amount, uint8 reason);
    event WorldExpanded(uint256 newZoneId, address triggeredBy);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address _afwToken) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        afwToken = _afwToken;
        baseBlockReward = 5 * 10 ** 18;
    }

    function registerNode(
        NodeTier tier,
        NodeSpec calldata spec,
        string calldata endpoint
    ) external {
        require(!nodes[msg.sender].isActive, "NodeRegistry: already registered");
        require(bytes(endpoint).length > 0, "NodeRegistry: empty endpoint");
        uint256 required = _getRequiredStake(tier);
        _removeActiveNode(msg.sender);

        nodes[msg.sender] = NodeInfo({
            operator: msg.sender,
            tier: tier,
            spec: spec,
            stakedAFW: required,
            registeredAt: block.timestamp,
            totalUptimeBlocks: 0,
            pendingReward: 0,
            totalSlashings: 0,
            isActive: true,
            endpoint: endpoint
        });

        activeNodes.push(msg.sender);
        emit NodeRegistered(msg.sender, tier, endpoint);
        _checkWorldExpansion();
    }

    function updateEndpoint(string calldata endpoint) external {
        require(nodes[msg.sender].isActive, "NodeRegistry: not active");
        require(bytes(endpoint).length > 0, "NodeRegistry: empty endpoint");
        nodes[msg.sender].endpoint = endpoint;
        emit NodeEndpointUpdated(msg.sender, endpoint);
    }

    function deactivateNode() external {
        _deactivateNode(msg.sender);
    }

    function deactivateNode(address node) external onlyRole(SLASHER_ROLE) {
        _deactivateNode(node);
    }

    function calculateReward(address node) public view returns (uint256) {
        NodeInfo storage info = nodes[node];
        if (!info.isActive || activeNodes.length == 0) return 0;

        uint256 tierMult = _getTierMult(info.tier);
        uint256 uptimePct = _getUptimePct(node);
        uint256 uptimeMult = uptimePct >= UPTIME_BONUS_THRESHOLD ? UPTIME_BONUS_MULT : 100;
        uint256 shareBps = 10000 / activeNodes.length;
        return baseBlockReward * tierMult / 100 * uptimeMult / 100 * shareBps / 10000;
    }

    function claimReward() external {
        NodeInfo storage info = nodes[msg.sender];
        require(info.isActive, "NodeRegistry: not active");
        uint256 amount = info.pendingReward;
        require(amount > 0, "NodeRegistry: nothing to claim");
        info.pendingReward = 0;
        emit RewardClaimed(msg.sender, amount);
    }

    function slash(address node, uint8 reason) external onlyRole(SLASHER_ROLE) {
        NodeInfo storage info = nodes[node];
        require(info.isActive, "NodeRegistry: not active");

        uint256 amount = reason == 2 ? info.stakedAFW : info.stakedAFW / 10;
        info.stakedAFW -= amount;
        info.totalSlashings++;

        if (info.stakedAFW < _getRequiredStake(info.tier)) {
            _deactivateNode(node);
        }

        emit NodeSlashed(node, amount, reason);
    }

    function getActiveNodeCount() external view returns (uint256) {
        return activeNodes.length;
    }

    function setBaseBlockReward(uint256 reward) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseBlockReward = reward;
    }

    function setWorldMap(address addr) external onlyRole(DEFAULT_ADMIN_ROLE) {
        worldMap = addr;
    }

    function _checkWorldExpansion() internal {
        uint256 active = activeNodes.length;
        if (active == 10 || active == 50 || active == 200) {
            emit WorldExpanded(active, msg.sender);
        }
    }

    function _deactivateNode(address node) internal {
        NodeInfo storage info = nodes[node];
        require(info.isActive, "NodeRegistry: not active");
        info.isActive = false;
        _removeActiveNode(node);
        emit NodeDeactivated(node);
    }

    function _removeActiveNode(address node) internal {
        uint256 length = activeNodes.length;
        for (uint256 i = 0; i < length; i++) {
            if (activeNodes[i] == node) {
                if (i != length - 1) {
                    activeNodes[i] = activeNodes[length - 1];
                }
                activeNodes.pop();
                return;
            }
        }
    }

    function _getRequiredStake(NodeTier tier) internal pure returns (uint256) {
        if (tier == NodeTier.GROWTH) return GROWTH_STAKE;
        if (tier == NodeTier.ELDER) return ELDER_STAKE;
        return SEED_STAKE;
    }

    function _getTierMult(NodeTier tier) internal pure returns (uint256) {
        if (tier == NodeTier.GROWTH) return GROWTH_MULT;
        if (tier == NodeTier.ELDER) return ELDER_MULT;
        return SEED_MULT;
    }

    function _getUptimePct(address) internal pure returns (uint256) {
        return 100;
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
