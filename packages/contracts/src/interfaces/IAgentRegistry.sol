// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAgentRegistry {
    struct Personality {
        uint8 bravery;
        uint8 greed;
        uint8 sociability;
        uint8 curiosity;
        uint8 loyalty;
    }

    struct Stats {
        uint32 hp;
        uint32 maxHp;
        uint32 mp;
        uint32 maxMp;
        uint32 attack;
        uint32 defense;
        uint32 speed;
    }

    struct Agent {
        uint256 agentId;
        address observer;
        uint256 classId;
        uint256 statusId;
        uint8 level;
        uint64 experience;
        uint256 zoneId;
        Personality personality;
        Stats stats;
        uint256 createdAt;
        uint256 lastActionBlock;
        bytes32 personalityHash;
    }

    function getAgent(uint256 agentId) external view returns (Agent memory);
    function getObserver(uint256 agentId) external view returns (address);
    function applyCombatResult(
        uint256 agentId,
        Stats calldata newStats,
        uint64 newExperience,
        uint256 newZoneId,
        uint256 newStatusId
    ) external;
}
