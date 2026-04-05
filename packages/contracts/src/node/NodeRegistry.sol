// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title NodeRegistry — 노드 등록/보상/슬래싱
 * @notice Proof of Compute: 에이전트 AI 추론 리소스 제공 → $AFW 보상
 *
 * 티어별 배율:
 *   SEED   (CPU만)       → 1.0x
 *   GROWTH (CPU+8GB GPU) → 2.5x
 *   ELDER  (CPU+24GB GPU)→ 6.0x
 *
 * 업타임 보너스: 99%+ → 1.2x 추가
 */
contract NodeRegistry is AccessControl {
    bytes32 public constant ORACLE_ROLE  = keccak256("ORACLE_ROLE");
    bytes32 public constant SLASHER_ROLE = keccak256("SLASHER_ROLE");

    enum NodeTier { SEED, GROWTH, ELDER }

    struct NodeSpec {
        uint8  cpuCores;
        uint32 ramGB;
        uint32 gpuVramGB;
        uint32 bandwidthMbps;
    }

    struct NodeInfo {
        address   operator;
        NodeTier  tier;
        NodeSpec  spec;
        uint256   stakedAFW;
        uint256   registeredAt;
        uint256   totalUptimeBlocks;
        uint256   pendingReward;     // 청구 대기 $AFW
        uint256   totalSlashings;
        bool      isActive;
        string    endpoint;          // 노드 API 엔드포인트
    }

    mapping(address => NodeInfo) public nodes;
    address[]                    public activeNodes;

    // 티어별 최소 스테이킹 ($AFW)
    uint256 public constant SEED_STAKE   =  1_000 * 10**18;
    uint256 public constant GROWTH_STAKE =  5_000 * 10**18;
    uint256 public constant ELDER_STAKE  = 20_000 * 10**18;

    // 티어별 배율 (100 = 1.0x)
    uint256 public constant SEED_MULT   = 100;
    uint256 public constant GROWTH_MULT = 250;
    uint256 public constant ELDER_MULT  = 600;

    uint256 public constant UPTIME_BONUS_MULT      = 120; // 1.2x
    uint256 public constant UPTIME_BONUS_THRESHOLD = 99;  // 99% 이상

    uint256 public baseBlockReward = 5 * 10**18; // 블록당 5 AFW (거버넌스로 조정)
    address public afwToken;
    address public worldMap;

    event NodeRegistered(address indexed operator, NodeTier tier, string endpoint);
    event NodeDeactivated(address indexed operator);
    event RewardClaimed(address indexed operator, uint256 amount);
    event NodeSlashed(address indexed operator, uint256 amount, uint8 reason);
    event WorldExpanded(uint256 newZoneId, address triggeredBy);

    constructor(address _afwToken) {
        afwToken = _afwToken;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // ─── 노드 등록 ───────────────────────────────────────────────
    function registerNode(
        NodeTier _tier,
        NodeSpec calldata _spec,
        string calldata _endpoint
    ) external {
        require(!nodes[msg.sender].isActive, "NodeRegistry: already registered");
        uint256 required = _getRequiredStake(_tier);
        // TODO: AFWToken.transferFrom(msg.sender, address(this), required)

        nodes[msg.sender] = NodeInfo({
            operator:          msg.sender,
            tier:              _tier,
            spec:              _spec,
            stakedAFW:         required,
            registeredAt:      block.timestamp,
            totalUptimeBlocks: 0,
            pendingReward:     0,
            totalSlashings:    0,
            isActive:          true,
            endpoint:          _endpoint
        });
        activeNodes.push(msg.sender);
        emit NodeRegistered(msg.sender, _tier, _endpoint);

        // 새 노드 합류 시 월드 확장 가능성 체크
        _checkWorldExpansion();
    }

    // ─── 보상 계산 ───────────────────────────────────────────────
    function calculateReward(address _node) public view returns (uint256) {
        NodeInfo storage n = nodes[_node];
        if (!n.isActive || activeNodes.length == 0) return 0;

        uint256 tierMult   = _getTierMult(n.tier);
        uint256 uptimePct  = _getUptimePct(_node);
        uint256 uptimeMult = uptimePct >= UPTIME_BONUS_THRESHOLD ? UPTIME_BONUS_MULT : 100;
        uint256 shareBps   = 10000 / activeNodes.length; // 균등 분배 (추후 리소스 비례로 개선)

        return baseBlockReward * tierMult / 100 * uptimeMult / 100 * shareBps / 10000;
    }

    function claimReward() external {
        NodeInfo storage n = nodes[msg.sender];
        require(n.isActive, "NodeRegistry: not active");
        uint256 amount = n.pendingReward;
        require(amount > 0, "NodeRegistry: nothing to claim");
        n.pendingReward = 0;
        // TODO: AFWToken.transfer(msg.sender, amount)
        emit RewardClaimed(msg.sender, amount);
    }

    // ─── 슬래싱 ─────────────────────────────────────────────────
    // reason: 0=잘못된결과 1=업타임미달 2=악의적조작
    function slash(address _node, uint8 _reason) external onlyRole(SLASHER_ROLE) {
        NodeInfo storage n = nodes[_node];
        require(n.isActive, "NodeRegistry: not active");

        uint256 amount = _reason == 2 ? n.stakedAFW : n.stakedAFW / 10;
        n.stakedAFW    -= amount;
        n.totalSlashings++;

        if (n.stakedAFW < _getRequiredStake(n.tier)) {
            n.isActive = false;
            emit NodeDeactivated(_node);
        }
        // TODO: 소각 또는 커뮤니티 펀드로
        emit NodeSlashed(_node, amount, _reason);
    }

    // ─── 월드 확장 트리거 ────────────────────────────────────────
    function _checkWorldExpansion() internal {
        uint256 active = activeNodes.length;
        // 10노드 → Graymarch, 50노드 → Embervault, 200노드 → Voidreach
        if (active == 10 || active == 50 || active == 200) {
            // TODO: WorldMap.unlockNextZone() 호출
            emit WorldExpanded(active, msg.sender);
        }
    }

    // ─── 내부 헬퍼 ─────────────────────────────────────────────
    function _getRequiredStake(NodeTier _t) internal pure returns (uint256) {
        if (_t == NodeTier.GROWTH) return GROWTH_STAKE;
        if (_t == NodeTier.ELDER)  return ELDER_STAKE;
        return SEED_STAKE;
    }

    function _getTierMult(NodeTier _t) internal pure returns (uint256) {
        if (_t == NodeTier.GROWTH) return GROWTH_MULT;
        if (_t == NodeTier.ELDER)  return ELDER_MULT;
        return SEED_MULT;
    }

    function _getUptimePct(address _node) internal view returns (uint256) {
        // TODO: 실제 업타임 측정 (OracleGateway 연동)
        return 100; // 임시: 100%
    }

    function getActiveNodeCount() external view returns (uint256) {
        return activeNodes.length;
    }

    function setBaseBlockReward(uint256 _reward) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseBlockReward = _reward;
    }
}
