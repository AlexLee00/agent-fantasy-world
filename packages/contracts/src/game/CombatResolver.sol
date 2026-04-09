// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IAgentRegistry.sol";
import "../interfaces/IMonsterRegistry.sol";
import "../interfaces/IEventTreasury.sol";
import "../interfaces/ISoulToken.sol";

/**
 * @title CombatResolver
 * @notice Settles agent-versus-monster combat on-chain.
 */
contract CombatResolver is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    uint256 public constant STATUS_ALIVE = 1;
    uint256 public constant STATUS_DEAD = 2;
    uint256 public constant STATUS_RESTING = 3;

    address public agentRegistry;
    address public monsterRegistry;
    address public soulToken;
    address public eventTreasury;

    event CombatSettled(uint256 indexed agentId, uint256 indexed monsterId, bool agentWins, uint256 soulDelta, uint256 xpDelta);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _agentRegistry,
        address _monsterRegistry,
        address _soulToken,
        address _eventTreasury
    ) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        agentRegistry = _agentRegistry;
        monsterRegistry = _monsterRegistry;
        soulToken = _soulToken;
        eventTreasury = _eventTreasury;
    }

    function resolveCombat(uint256 agentId, uint256 monsterId) external returns (bool agentWins) {
        IAgentRegistry.Agent memory agent = IAgentRegistry(agentRegistry).getAgent(agentId);
        IMonsterRegistry.Monster memory monster = IMonsterRegistry(monsterRegistry).getMonster(monsterId);
        require(monster.alive, "CombatResolver: monster dead");

        uint256 agentDamage = _scaledDamage(agent.stats.attack, monster.def, agent.classId, agentId, monsterId);
        uint256 monsterDamage = _scaledDamage(monster.atk, agent.stats.defense, 0, monsterId, agentId);
        uint256 rounds = (monster.hp + agentDamage - 1) / agentDamage;
        uint256 totalMonsterDamage = rounds * monsterDamage;

        if (agent.stats.hp > totalMonsterDamage) {
            uint256 hpAfter = agent.stats.hp - totalMonsterDamage;
            uint256 reward = IMonsterRegistry(monsterRegistry).killMonster(monsterId);
            uint64 xpGain = uint64(25 + reward / 10 ** 18);
            if (reward > 0) {
                ISoulToken(soulToken).mint(agent.observer, reward, "MONSTER_LOOT", monsterId);
            }

            IAgentRegistry.Stats memory statsAfter = agent.stats;
            statsAfter.hp = uint32(hpAfter);
            IAgentRegistry(agentRegistry).applyCombatResult(
                agentId,
                statsAfter,
                agent.experience + xpGain,
                agent.zoneId,
                STATUS_ALIVE
            );

            emit CombatSettled(agentId, monsterId, true, reward, xpGain);
            return true;
        }

        (uint256 lootAmount, uint256 xpLost) = _resolveMonsterVictory(agentId, monsterId, agent);
        emit CombatSettled(agentId, monsterId, false, lootAmount, xpLost);
        return false;
    }

    function _resolveMonsterVictory(
        uint256 agentId,
        uint256 monsterId,
        IAgentRegistry.Agent memory agent
    ) internal returns (uint256 lootAmount, uint256 xpLost) {
        uint256 playerSoul = ISoulToken(soulToken).balanceOf(agent.observer);
        lootAmount = playerSoul * 3000 / 10000;
        uint256 xpLossBps = 1000 + (_random(agentId, monsterId, "XP") % 2001);
        xpLost = uint256(agent.experience) * xpLossBps / 10000;
        uint64 xpAfter = uint64(uint256(agent.experience) - xpLost);

        if (lootAmount > 0) {
            ISoulToken(soulToken).burn(agent.observer, lootAmount, "MONSTER_LOOT");
            (, uint256 treasuryShare) = IMonsterRegistry(monsterRegistry).monsterWins(monsterId, lootAmount);
            if (treasuryShare > 0) {
                ISoulToken(soulToken).mint(eventTreasury, treasuryShare, "EVENT_TREASURY", monsterId);
            }
        }

        IAgentRegistry.Stats memory revivedStats = agent.stats;
        revivedStats.hp = revivedStats.maxHp;
        revivedStats.mp = revivedStats.maxMp;
        IAgentRegistry(agentRegistry).applyCombatResult(agentId, revivedStats, xpAfter, 1, STATUS_RESTING);
    }

    function _scaledDamage(
        uint256 attackValue,
        uint256 defenseValue,
        uint256 classId,
        uint256 seedA,
        uint256 seedB
    ) internal view returns (uint256) {
        uint256 damageBase = attackValue * 100 / (100 + defenseValue);
        uint256 classBps = _classModifierBps(classId);
        uint256 randomFactorBps = 8000 + (_random(seedA, seedB, "DMG") % 4001);
        uint256 damage = damageBase * classBps / 10000;
        damage = damage * randomFactorBps / 10000;
        return damage == 0 ? 1 : damage;
    }

    function _classModifierBps(uint256 classId) internal pure returns (uint256) {
        if (classId == 1) return 10000;
        if (classId == 2) return 13000;
        if (classId == 3) return 11000;
        if (classId == 4) return 6000;
        if (classId == 5) return 8000;
        return 10000;
    }

    function _random(uint256 a, uint256 b, string memory salt) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.prevrandao, block.timestamp, a, b, salt)));
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
