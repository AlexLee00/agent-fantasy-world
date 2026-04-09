// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IItemRegistry.sol";

/**
 * @title NPCRegistry
 * @notice Manages NPC types, spawned NPCs, price tables, and supply-chain trades.
 */
contract NPCRegistry is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    uint256 public constant TAVERN_REST_PRICE = 5 * 10 ** 18;
    uint256 public constant BASIC_HEALTH_POTION_PRICE = 10 * 10 ** 18;
    uint256 public constant IRON_SWORD_PRICE = 50 * 10 ** 18;
    uint256 public constant LEATHER_ARMOR_PRICE = 40 * 10 ** 18;
    uint256 public constant QUEST_BOARD_POSTING_PRICE = 3 * 10 ** 18;
    uint256 public constant BASIC_SPELL_SCROLL_PRICE = 30 * 10 ** 18;

    struct NPCType {
        string name;
        string role;
        uint256 zoneId;
        address creator;
        bool active;
    }

    struct NPC {
        uint256 typeId;
        uint256 soulBalance;
        uint256 zoneId;
        bool active;
    }

    struct PriceEntry {
        uint256 itemId;
        uint256 price;
        bool available;
    }

    mapping(uint256 => NPCType) public npcTypes;
    mapping(uint256 => NPC) public npcs;
    mapping(uint256 => mapping(uint256 => PriceEntry)) public npcPrices;

    uint256 public totalNPCTypes;
    uint256 public totalNPCs;
    address public itemRegistry;
    address public soulToken;

    event NPCTypeRegistered(uint256 indexed typeId, string name, string role);
    event NPCSpawned(uint256 indexed npcId, uint256 indexed typeId, uint256 zoneId);
    event PriceSet(uint256 indexed npcId, uint256 indexed itemId, uint256 price);
    event NPCPurchase(uint256 indexed npcId, address indexed buyer, uint256 itemId, uint256 price);
    event SupplyChainPurchase(uint256 indexed buyerId, uint256 indexed sellerId, uint256 itemId, uint256 price);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address _itemRegistry, address _soulToken) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        itemRegistry = _itemRegistry;
        soulToken = _soulToken;
    }

    function registerNPCType(
        string calldata name,
        string calldata role,
        uint256 zoneId
    ) external returns (uint256 typeId) {
        typeId = ++totalNPCTypes;
        npcTypes[typeId] = NPCType({
            name: name,
            role: role,
            zoneId: zoneId,
            creator: msg.sender,
            active: true
        });

        emit NPCTypeRegistered(typeId, name, role);
    }

    function spawnNPC(uint256 typeId, uint256 zoneId, uint256 initialSOUL) external returns (uint256 npcId) {
        require(npcTypes[typeId].active, "NPCRegistry: type inactive");

        npcId = ++totalNPCs;
        npcs[npcId] = NPC({
            typeId: typeId,
            soulBalance: initialSOUL,
            zoneId: zoneId,
            active: true
        });

        emit NPCSpawned(npcId, typeId, zoneId);
    }

    function setPrice(uint256 npcId, uint256 itemId, uint256 price) external {
        require(npcs[npcId].active, "NPCRegistry: npc inactive");
        require(price > 0, "NPCRegistry: invalid price");
        npcPrices[npcId][itemId] = PriceEntry({
            itemId: itemId,
            price: price,
            available: true
        });
        emit PriceSet(npcId, itemId, price);
    }

    function buyFromNPC(uint256 npcId, uint256 itemId) external {
        PriceEntry storage entry = npcPrices[npcId][itemId];
        require(entry.available, "NPCRegistry: item unavailable");
        IERC20(soulToken).transferFrom(msg.sender, address(this), entry.price);
        npcs[npcId].soulBalance += entry.price;
        IItemRegistry(itemRegistry).mint(msg.sender, itemId, 1);
        emit NPCPurchase(npcId, msg.sender, itemId, entry.price);
    }

    function npcBuyFromNPC(uint256 buyerId, uint256 sellerId, uint256 itemId) external {
        PriceEntry storage entry = npcPrices[sellerId][itemId];
        require(entry.available, "NPCRegistry: seller item unavailable");
        require(npcs[buyerId].soulBalance >= entry.price, "NPCRegistry: insufficient soul");

        npcs[buyerId].soulBalance -= entry.price;
        npcs[sellerId].soulBalance += entry.price;
        emit SupplyChainPurchase(buyerId, sellerId, itemId, entry.price);
    }

    function getBasePriceAnchor(uint256 anchorId) external pure returns (uint256) {
        if (anchorId == 1) return TAVERN_REST_PRICE;
        if (anchorId == 2) return BASIC_HEALTH_POTION_PRICE;
        if (anchorId == 3) return IRON_SWORD_PRICE;
        if (anchorId == 4) return LEATHER_ARMOR_PRICE;
        if (anchorId == 5) return QUEST_BOARD_POSTING_PRICE;
        if (anchorId == 6) return BASIC_SPELL_SCROLL_PRICE;
        revert("NPCRegistry: unknown anchor");
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
