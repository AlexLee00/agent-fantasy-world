// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/ISoulToken.sol";

/**
 * @title EconomyEngine — unified $SOUL mint and burn gateway
 * @notice Gameplay-driven supply model with no daily mint cap.
 */
contract EconomyEngine is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant QUEST_ROLE = keccak256("QUEST_ROLE");
    bytes32 public constant COMBAT_ROLE = keccak256("COMBAT_ROLE");
    bytes32 public constant MARKET_ROLE = keccak256("MARKET_ROLE");

    uint256 public constant DEATH_LOOT_BPS = 3000;
    uint256 public constant MONSTER_LOOT_BPS = 1500;
    uint256 public constant TREASURY_LOOT_BPS = 1500;

    address public soulToken;
    address public eventTreasury;

    uint256 public marketFeeBurnBps;
    uint256 public deathXpLossBps;

    mapping(uint256 => uint256) public dailyMinted;
    mapping(uint256 => uint256) public dailyBurned;

    uint256 public totalMinted;
    uint256 public totalBurned;

    event SOULMinted(address indexed to, uint256 amount, string reason, uint256 refId);
    event SOULBurned(address indexed from, uint256 amount, string reason);
    event EventTreasuryUpdated(address indexed eventTreasury);
    event AgentDeathProcessed(
        address indexed agentWallet,
        address indexed monsterWallet,
        uint256 soulLost,
        uint256 monsterShare,
        uint256 treasuryShare,
        uint256 xpLost
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address _soulToken, address _eventTreasury) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        soulToken = _soulToken;
        eventTreasury = _eventTreasury;
        marketFeeBurnBps = 200;
        deathXpLossBps = 1000;
    }

    function mintForQuest(address to, uint256 amount, uint256 questId) external onlyRole(QUEST_ROLE) {
        _mint(to, amount, "QUEST", questId);
    }

    function mintForCombat(address to, uint256 amount, uint256 monsterId) external onlyRole(COMBAT_ROLE) {
        _mint(to, amount, "COMBAT", monsterId);
    }

    function mintForExplore(address to, uint256 amount, uint256 zoneId) external onlyRole(QUEST_ROLE) {
        _mint(to, amount, "EXPLORE", zoneId);
    }

    function burnForItemPurchase(address from, uint256 amount) external onlyRole(MARKET_ROLE) {
        _burn(from, amount, "ITEM_PURCHASE");
    }

    function burnMarketFee(address from, uint256 tradeAmount) external onlyRole(MARKET_ROLE) {
        uint256 fee = tradeAmount * marketFeeBurnBps / 10000;
        _burn(from, fee, "MARKET_FEE");
    }

    function processDeath(
        address agentWallet,
        address monsterWallet,
        uint256 currentXp,
        uint256 refId
    ) external onlyRole(COMBAT_ROLE) returns (uint256 soulLost, uint256 xpLost) {
        uint256 balance = ISoulToken(soulToken).balanceOf(agentWallet);
        soulLost = balance * DEATH_LOOT_BPS / 10000;

        uint256 monsterShare = soulLost * MONSTER_LOOT_BPS / DEATH_LOOT_BPS;
        uint256 treasuryShare = soulLost - monsterShare;

        if (soulLost > 0) {
            _burn(agentWallet, soulLost, "DEATH_LOOT");
            if (monsterShare > 0) {
                _mint(monsterWallet, monsterShare, "DEATH_LOOT_MONSTER", refId);
            }
            if (treasuryShare > 0) {
                _mint(eventTreasury, treasuryShare, "DEATH_LOOT_TREASURY", refId);
            }
        }

        xpLost = currentXp * deathXpLossBps / 10000;
        emit AgentDeathProcessed(agentWallet, monsterWallet, soulLost, monsterShare, treasuryShare, xpLost);
    }

    function getTodayMinted() external view returns (uint256) {
        return dailyMinted[block.timestamp / 1 days];
    }

    function getTodayBurned() external view returns (uint256) {
        return dailyBurned[block.timestamp / 1 days];
    }

    function getInflationBps() external view returns (int256) {
        if (totalMinted == 0) return 0;

        uint256 today = block.timestamp / 1 days;
        uint256 minted = dailyMinted[today];
        uint256 burned = dailyBurned[today];
        return int256(minted * 10000 / totalMinted) - int256(burned * 10000 / totalMinted);
    }

    function setEventTreasury(address treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        eventTreasury = treasury;
        emit EventTreasuryUpdated(treasury);
    }

    function setMarketFeeBurnBps(uint256 bps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(bps <= 1000, "EconomyEngine: burn too high");
        marketFeeBurnBps = bps;
    }

    function setDeathXpLossBps(uint256 bps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(bps <= 5000, "EconomyEngine: xp loss too high");
        deathXpLossBps = bps;
    }

    function _mint(address to, uint256 amount, string memory reason, uint256 refId) internal {
        if (amount == 0) {
            return;
        }

        totalMinted += amount;
        dailyMinted[block.timestamp / 1 days] += amount;
        ISoulToken(soulToken).mint(to, amount, reason, refId);
        emit SOULMinted(to, amount, reason, refId);
    }

    function _burn(address from, uint256 amount, string memory reason) internal {
        if (amount == 0) {
            return;
        }

        totalBurned += amount;
        dailyBurned[block.timestamp / 1 days] += amount;
        ISoulToken(soulToken).burn(from, amount, reason);
        emit SOULBurned(from, amount, reason);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
