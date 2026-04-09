// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title WorldMap — zone definition and expansion management
 * @notice Uses an open registry-based danger level system instead of a fixed enum.
 */
contract WorldMap is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant NODE_REGISTRY_ROLE = keccak256("NODE_REGISTRY_ROLE");

    struct DangerLevelDefinition {
        uint256 dangerId;
        string name;
        uint8 minLevel;
        uint8 maxLevel;
        bool exists;
    }

    struct Zone {
        uint256 zoneId;
        string name;
        string koreanName;
        uint256 dangerId;
        uint256 requiredNodes;
        uint256 maxAgents;
        bool isUnlocked;
        uint256[] connections;
        uint256 unlockedAt;
    }

    mapping(uint256 => Zone) public zones;
    mapping(uint256 => DangerLevelDefinition) public dangerLevels;

    uint256 public totalZones;
    uint256 public unlockedZones;
    uint256 public totalDangerLevels;

    event ZoneUnlocked(uint256 indexed zoneId, string name, uint256 nodeCount);
    event ZoneRegistered(uint256 indexed zoneId, string name, uint256 requiredNodes);
    event DangerLevelRegistered(uint256 indexed dangerId, string name, uint8 minLevel, uint8 maxLevel);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function registerDangerLevel(
        string calldata name,
        uint8 minLevel,
        uint8 maxLevel
    ) external returns (uint256 dangerId) {
        require(minLevel >= 1, "WorldMap: min level too low");
        require(maxLevel <= 99, "WorldMap: max level too high");
        require(minLevel <= maxLevel, "WorldMap: invalid level range");

        dangerId = ++totalDangerLevels;
        dangerLevels[dangerId] = DangerLevelDefinition({
            dangerId: dangerId,
            name: name,
            minLevel: minLevel,
            maxLevel: maxLevel,
            exists: true
        });

        emit DangerLevelRegistered(dangerId, name, minLevel, maxLevel);
    }

    function registerZone(
        string calldata name,
        string calldata koreanName,
        uint256 dangerId,
        uint256 requiredNodes,
        uint256 maxAgents,
        uint256[] calldata connections
    ) public returns (uint256 zoneId) {
        require(dangerLevels[dangerId].exists, "WorldMap: danger not found");
        require(maxAgents > 0, "WorldMap: max agents required");

        zoneId = ++totalZones;
        bool shouldUnlock = requiredNodes <= 1;

        zones[zoneId] = Zone({
            zoneId: zoneId,
            name: name,
            koreanName: koreanName,
            dangerId: dangerId,
            requiredNodes: requiredNodes,
            maxAgents: maxAgents,
            isUnlocked: shouldUnlock,
            connections: connections,
            unlockedAt: shouldUnlock ? block.number : 0
        });

        if (shouldUnlock) {
            unlockedZones++;
        }

        emit ZoneRegistered(zoneId, name, requiredNodes);
    }

    function addCommunityZone(
        string calldata name,
        string calldata koreanName,
        uint256 dangerId,
        uint256 requiredNodes,
        uint256 maxAgents,
        uint256[] calldata connections
    ) external returns (uint256 zoneId) {
        return registerZone(name, koreanName, dangerId, requiredNodes, maxAgents, connections);
    }

    function checkAndUnlock(uint256 currentNodeCount) external onlyRole(NODE_REGISTRY_ROLE) {
        for (uint256 i = 1; i <= totalZones; i++) {
            Zone storage zone = zones[i];
            if (!zone.isUnlocked && currentNodeCount >= zone.requiredNodes) {
                zone.isUnlocked = true;
                zone.unlockedAt = block.number;
                unlockedZones++;
                emit ZoneUnlocked(i, zone.name, currentNodeCount);
            }
        }
    }

    function getZone(uint256 zoneId) external view returns (Zone memory) {
        return zones[zoneId];
    }

    function getZoneConnections(uint256 zoneId) external view returns (uint256[] memory) {
        return zones[zoneId].connections;
    }

    function isZoneUnlocked(uint256 zoneId) external view returns (bool) {
        return zones[zoneId].isUnlocked;
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
