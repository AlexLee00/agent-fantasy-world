// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IEventTreasury.sol";

/**
 * @title MonsterRegistry
 * @notice Registers monster types and spawns live monster instances with internal wallets.
 */
contract MonsterRegistry is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant COMBAT_ROLE = keccak256("COMBAT_ROLE");

    struct MonsterType {
        string name;
        uint256 dangerLevel;
        uint256 minHP;
        uint256 maxHP;
        uint256 minATK;
        uint256 maxATK;
        uint256 minDEF;
        uint256 maxDEF;
        uint256 minSOUL;
        uint256 maxSOUL;
        address creator;
        bool active;
    }

    struct Monster {
        uint256 typeId;
        uint256 hp;
        uint256 atk;
        uint256 def;
        uint256 soulBalance;
        uint256 zoneId;
        bool alive;
    }

    mapping(uint256 => MonsterType) public monsterTypes;
    mapping(uint256 => Monster) public monsters;

    uint256 public totalMonsterTypes;
    uint256 public totalMonsters;
    address public eventTreasury;

    event MonsterTypeRegistered(uint256 indexed typeId, string name, uint256 dangerLevel);
    event MonsterSpawned(uint256 indexed monsterId, uint256 indexed typeId, uint256 zoneId);
    event MonsterKilled(uint256 indexed monsterId, uint256 soulReward);
    event MonsterLooted(uint256 indexed monsterId, uint256 monsterShare, uint256 treasuryShare);
    event EventTreasuryUpdated(address indexed treasury);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function registerMonsterType(
        string calldata name,
        uint256 dangerLevel,
        uint256 minHP,
        uint256 maxHP,
        uint256 minATK,
        uint256 maxATK,
        uint256 minDEF,
        uint256 maxDEF,
        uint256 minSOUL,
        uint256 maxSOUL
    ) external returns (uint256 typeId) {
        _validateSpec(dangerLevel, minHP, maxHP, minATK, maxATK, minDEF, maxDEF, minSOUL, maxSOUL);

        typeId = ++totalMonsterTypes;
        monsterTypes[typeId] = MonsterType({
            name: name,
            dangerLevel: dangerLevel,
            minHP: minHP,
            maxHP: maxHP,
            minATK: minATK,
            maxATK: maxATK,
            minDEF: minDEF,
            maxDEF: maxDEF,
            minSOUL: minSOUL,
            maxSOUL: maxSOUL,
            creator: msg.sender,
            active: true
        });

        emit MonsterTypeRegistered(typeId, name, dangerLevel);
    }

    function spawnMonster(uint256 typeId, uint256 zoneId) external returns (uint256 monsterId) {
        MonsterType storage monsterType = monsterTypes[typeId];
        require(monsterType.active, "MonsterRegistry: type inactive");

        monsterId = ++totalMonsters;
        bytes32 seed = keccak256(abi.encodePacked(typeId, zoneId, monsterId, block.prevrandao, block.timestamp));
        monsters[monsterId] = Monster({
            typeId: typeId,
            hp: _roll(monsterType.minHP, monsterType.maxHP, seed, "HP"),
            atk: _roll(monsterType.minATK, monsterType.maxATK, seed, "ATK"),
            def: _roll(monsterType.minDEF, monsterType.maxDEF, seed, "DEF"),
            soulBalance: _roll(monsterType.minSOUL, monsterType.maxSOUL, seed, "SOUL") * 10 ** 18,
            zoneId: zoneId,
            alive: true
        });

        emit MonsterSpawned(monsterId, typeId, zoneId);
    }

    function getMonster(uint256 monsterId) external view returns (Monster memory) {
        return monsters[monsterId];
    }

    function getMonsterType(uint256 typeId) external view returns (MonsterType memory) {
        return monsterTypes[typeId];
    }

    function killMonster(uint256 monsterId) external onlyRole(COMBAT_ROLE) returns (uint256 reward) {
        Monster storage monster = monsters[monsterId];
        require(monster.alive, "MonsterRegistry: already dead");
        reward = monster.soulBalance;
        monster.soulBalance = 0;
        monster.alive = false;
        emit MonsterKilled(monsterId, reward);
    }

    function monsterWins(uint256 monsterId, uint256 lootAmount)
        external
        onlyRole(COMBAT_ROLE)
        returns (uint256 monsterShare, uint256 treasuryShare)
    {
        Monster storage monster = monsters[monsterId];
        require(monster.alive, "MonsterRegistry: monster dead");

        monsterShare = lootAmount / 2;
        treasuryShare = lootAmount - monsterShare;
        monster.soulBalance += monsterShare;

        if (eventTreasury != address(0) && treasuryShare > 0) {
            IEventTreasury(eventTreasury).deposit(treasuryShare);
        }

        emit MonsterLooted(monsterId, monsterShare, treasuryShare);
    }

    function setEventTreasury(address treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        eventTreasury = treasury;
        emit EventTreasuryUpdated(treasury);
    }

    function _validateSpec(
        uint256 dangerLevel,
        uint256 minHP,
        uint256 maxHP,
        uint256 minATK,
        uint256 maxATK,
        uint256 minDEF,
        uint256 maxDEF,
        uint256 minSOUL,
        uint256 maxSOUL
    ) internal pure {
        require(dangerLevel >= 1 && dangerLevel <= 4, "MonsterRegistry: invalid danger");
        require(minHP <= maxHP && minATK <= maxATK && minDEF <= maxDEF && minSOUL <= maxSOUL, "MonsterRegistry: invalid range");

        if (dangerLevel == 1) {
            require(minHP >= 20 && maxHP <= 100, "MonsterRegistry: hp out of range");
            require(minATK >= 5 && maxATK <= 15, "MonsterRegistry: atk out of range");
            require(minDEF >= 3 && maxDEF <= 10, "MonsterRegistry: def out of range");
            require(minSOUL >= 5 && maxSOUL <= 20, "MonsterRegistry: soul out of range");
            return;
        }
        if (dangerLevel == 2) {
            require(minHP >= 80 && maxHP <= 300, "MonsterRegistry: hp out of range");
            require(minATK >= 12 && maxATK <= 25, "MonsterRegistry: atk out of range");
            require(minDEF >= 8 && maxDEF <= 18, "MonsterRegistry: def out of range");
            require(minSOUL >= 20 && maxSOUL <= 50, "MonsterRegistry: soul out of range");
            return;
        }
        if (dangerLevel == 3) {
            require(minHP >= 200 && maxHP <= 600, "MonsterRegistry: hp out of range");
            require(minATK >= 20 && maxATK <= 40, "MonsterRegistry: atk out of range");
            require(minDEF >= 15 && maxDEF <= 30, "MonsterRegistry: def out of range");
            require(minSOUL >= 80 && maxSOUL <= 150, "MonsterRegistry: soul out of range");
            return;
        }

        require(minHP >= 500 && maxHP <= 2000, "MonsterRegistry: hp out of range");
        require(minATK >= 35 && maxATK <= 80, "MonsterRegistry: atk out of range");
        require(minDEF >= 25 && maxDEF <= 60, "MonsterRegistry: def out of range");
        require(minSOUL >= 200 && maxSOUL <= 500, "MonsterRegistry: soul out of range");
    }

    function _roll(uint256 minValue, uint256 maxValue, bytes32 seed, string memory salt) internal pure returns (uint256) {
        if (minValue == maxValue) {
            return minValue;
        }
        return minValue + (uint256(keccak256(abi.encodePacked(seed, salt))) % (maxValue - minValue + 1));
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
