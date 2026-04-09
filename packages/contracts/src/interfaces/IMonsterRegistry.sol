// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMonsterRegistry {
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

    function getMonster(uint256 monsterId) external view returns (Monster memory);
    function getMonsterType(uint256 typeId) external view returns (MonsterType memory);
    function killMonster(uint256 monsterId) external returns (uint256);
    function monsterWins(uint256 monsterId, uint256 lootAmount) external returns (uint256 monsterShare, uint256 treasuryShare);
}
