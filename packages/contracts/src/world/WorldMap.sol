// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title WorldMap — Zone 정의 및 확장 관리
 * @notice 노드 제공자가 리소스를 늘릴수록 세계가 넓어진다
 *
 * Zone 구조:
 *   1 Lumenveil  (마을,  SAFE,   nodes >= 1)   ← 초기 생성
 *   2 Graymarch  (평원,  MEDIUM, nodes >= 10)
 *   3 Embervault (던전,  DANGER, nodes >= 50)
 *   4 Voidreach  (심연,  EXTREME,nodes >= 200)
 */
contract WorldMap is AccessControl {
    bytes32 public constant NODE_REGISTRY_ROLE = keccak256("NODE_REGISTRY_ROLE");

    enum DangerLevel { SAFE, MEDIUM, DANGER, EXTREME }

    struct Zone {
        uint256      zoneId;
        string       name;
        string       koreanName;
        DangerLevel  danger;
        uint256      requiredNodes;  // 언락에 필요한 노드 수
        uint256      maxAgents;
        bool         isUnlocked;
        uint256[]    connections;    // 연결된 Zone
        uint256      unlockedAt;     // 언락 시 블록 번호
    }

    mapping(uint256 => Zone) public zones;
    uint256 public totalZones;
    uint256 public unlockedZones;

    event ZoneUnlocked(uint256 indexed zoneId, string name, uint256 nodeCount);
    event ZoneAdded(uint256 indexed zoneId, string name, uint256 requiredNodes);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Zone 1: Lumenveil — 시작 시 즉시 언락
        _addZone("Lumenveil", "빛의 베일", DangerLevel.SAFE, 1, 100, new uint256[](0));
        zones[1].isUnlocked = true;
        zones[1].unlockedAt = block.number;
        unlockedZones = 1;

        // Zone 2~4: 잠김 상태로 등록
        uint256[] memory z1conn = new uint256[](1); z1conn[0] = 1;
        _addZone("Graymarch",  "회색 행진", DangerLevel.MEDIUM,  10,  200, z1conn);

        uint256[] memory z2conn = new uint256[](1); z2conn[0] = 2;
        _addZone("Embervault", "잿불 지하", DangerLevel.DANGER,  50,  150, z2conn);

        uint256[] memory z3conn = new uint256[](1); z3conn[0] = 3;
        _addZone("Voidreach",  "공허의 끝", DangerLevel.EXTREME, 200,  50, z3conn);
    }

    function _addZone(
        string memory _name,
        string memory _korean,
        DangerLevel   _danger,
        uint256 _reqNodes,
        uint256 _maxAgents,
        uint256[] memory _connections
    ) internal {
        uint256 id = ++totalZones;
        zones[id] = Zone({
            zoneId:       id,
            name:         _name,
            koreanName:   _korean,
            danger:       _danger,
            requiredNodes: _reqNodes,
            maxAgents:    _maxAgents,
            isUnlocked:   false,
            connections:  _connections,
            unlockedAt:   0
        });
        emit ZoneAdded(id, _name, _reqNodes);
    }

    // ─── 노드 증가 시 자동 언락 트리거 ──────────────────────────
    function checkAndUnlock(uint256 _currentNodeCount)
        external onlyRole(NODE_REGISTRY_ROLE)
    {
        for (uint256 i = 1; i <= totalZones; i++) {
            Zone storage z = zones[i];
            if (!z.isUnlocked && _currentNodeCount >= z.requiredNodes) {
                z.isUnlocked  = true;
                z.unlockedAt  = block.number;
                unlockedZones++;
                emit ZoneUnlocked(i, z.name, _currentNodeCount);
            }
        }
    }

    // ─── 커뮤니티가 새 Zone 추가 (거버넌스 승인 후) ─────────────
    function addCommunityZone(
        string calldata _name,
        string calldata _korean,
        DangerLevel     _danger,
        uint256 _reqNodes,
        uint256 _maxAgents,
        uint256[] calldata _connections
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _addZone(_name, _korean, _danger, _reqNodes, _maxAgents, _connections);
    }

    function getZone(uint256 _id) external view returns (Zone memory) {
        return zones[_id];
    }

    function getZoneConnections(uint256 _id) external view returns (uint256[] memory) {
        return zones[_id].connections;
    }

    function isZoneUnlocked(uint256 _id) external view returns (bool) {
        return zones[_id].isUnlocked;
    }
}
