// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title EconomyEngine — $SOUL 발행/소각 통합 게이트웨이
 * @notice 모든 발행/소각은 이 컨트랙트를 통해서만 처리
 *         인플레이션 자동 모니터링 + 일일 한도 강제
 */
contract EconomyEngine is AccessControl {
    bytes32 public constant QUEST_ROLE   = keccak256("QUEST_ROLE");
    bytes32 public constant COMBAT_ROLE  = keccak256("COMBAT_ROLE");
    bytes32 public constant MARKET_ROLE  = keccak256("MARKET_ROLE");

    address public soulToken;

    uint256 public dailyMintLimit      = 1_000_000 * 10**18; // 일일 100만 SOUL
    uint256 public marketFeeBurnBps    = 200;  // 마켓 수수료 2% 소각
    uint256 public revivalCostSoul     = 500 * 10**18; // 부활 비용 500 SOUL

    mapping(uint256 => uint256) public dailyMinted; // day → amount
    mapping(uint256 => uint256) public dailyBurned;

    uint256 public totalMinted;
    uint256 public totalBurned;

    event SOULMinted(address indexed to,   uint256 amount, string reason, uint256 refId);
    event SOULBurned(address indexed from, uint256 amount, string reason);
    event DailyLimitUpdated(uint256 newLimit);

    constructor(address _soulToken) {
        soulToken = _soulToken;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // ─── 발행 게이트웨이 ─────────────────────────────────────────
    function mintForQuest(address _to, uint256 _amount, uint256 _questId)
        external onlyRole(QUEST_ROLE)
    {
        _enforceDailyLimit(_amount);
        _mint(_to, _amount, "QUEST", _questId);
    }

    function mintForCombat(address _to, uint256 _amount, uint256 _monsterId)
        external onlyRole(COMBAT_ROLE)
    {
        _enforceDailyLimit(_amount);
        _mint(_to, _amount, "COMBAT", _monsterId);
    }

    function mintForExplore(address _to, uint256 _amount, uint256 _zoneId)
        external onlyRole(QUEST_ROLE)
    {
        _enforceDailyLimit(_amount);
        _mint(_to, _amount, "EXPLORE", _zoneId);
    }

    // ─── 소각 게이트웨이 ─────────────────────────────────────────
    function burnForItemPurchase(address _from, uint256 _amount)
        external onlyRole(MARKET_ROLE)
    {
        _burn(_from, _amount, "ITEM_PURCHASE");
    }

    function burnForRevival(address _observer, uint256 _agentId)
        external
    {
        // TODO: AgentRegistry에서 에이전트 부활 확인
        _burn(_observer, revivalCostSoul, "REVIVAL");
        emit SOULBurned(_observer, revivalCostSoul, string(abi.encodePacked("REVIVAL:", _agentId)));
    }

    function burnMarketFee(uint256 _tradeAmount) external onlyRole(MARKET_ROLE) {
        uint256 fee = _tradeAmount * marketFeeBurnBps / 10000;
        // TODO: 수수료를 SOULToken.burn()으로 실제 소각
        totalBurned += fee;
        uint256 today = block.timestamp / 1 days;
        dailyBurned[today] += fee;
        emit SOULBurned(address(this), fee, "MARKET_FEE");
    }

    // ─── 인플레이션 모니터링 ─────────────────────────────────────
    function getTodayMinted() external view returns (uint256) {
        return dailyMinted[block.timestamp / 1 days];
    }

    function getTodayBurned() external view returns (uint256) {
        return dailyBurned[block.timestamp / 1 days];
    }

    // 양수 = 인플레이션, 음수 = 디플레이션 (basis points)
    function getInflationBps() external view returns (int256) {
        uint256 today   = block.timestamp / 1 days;
        uint256 minted  = dailyMinted[today];
        uint256 burned  = dailyBurned[today];
        if (totalMinted == 0) return 0;
        return int256(minted * 10000 / totalMinted) - int256(burned * 10000 / totalMinted);
    }

    // ─── 내부 ────────────────────────────────────────────────────
    function _enforceDailyLimit(uint256 _amount) internal {
        uint256 today = block.timestamp / 1 days;
        require(dailyMinted[today] + _amount <= dailyMintLimit, "EconomyEngine: daily limit");
        dailyMinted[today] += _amount;
        totalMinted        += _amount;
    }

    function _mint(address _to, uint256 _amount, string memory _reason, uint256 _refId) internal {
        // TODO: SOULToken(soulToken).mint(_to, _amount, _reason, _refId)
        emit SOULMinted(_to, _amount, _reason, _refId);
    }

    function _burn(address _from, uint256 _amount, string memory _reason) internal {
        // TODO: SOULToken(soulToken).burn(_from, _amount, _reason)
        totalBurned += _amount;
        uint256 today = block.timestamp / 1 days;
        dailyBurned[today] += _amount;
        emit SOULBurned(_from, _amount, _reason);
    }

    function setDailyMintLimit(uint256 _limit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        dailyMintLimit = _limit;
        emit DailyLimitUpdated(_limit);
    }

    function setRevivalCost(uint256 _cost) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revivalCostSoul = _cost;
    }
}
