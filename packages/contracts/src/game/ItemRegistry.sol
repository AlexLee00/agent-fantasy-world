// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

/**
 * @title ItemRegistry
 * @notice ERC-1155 registry for all game items.
 */
contract ItemRegistry is Initializable, ERC1155Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    struct ItemType {
        string name;
        string category;
        uint256 tier;
        uint256 minStat;
        uint256 maxStat;
        address creator;
        bool tradeable;
    }

    mapping(uint256 => ItemType) public itemTypes;
    uint256 public totalItemTypes;

    event ItemTypeRegistered(uint256 indexed itemId, string name, string category, uint256 tier);
    event BaseUriUpdated(string newUri);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, string calldata baseUri) external initializer {
        __ERC1155_init(baseUri);
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function registerItemType(
        string calldata name,
        string calldata category,
        uint256 tier,
        uint256 minStat,
        uint256 maxStat,
        bool tradeable
    ) external returns (uint256 itemId) {
        require(tier >= 1 && tier <= 5, "ItemRegistry: invalid tier");
        require(minStat <= maxStat, "ItemRegistry: invalid stat range");

        (uint256 minAllowed, uint256 maxAllowed) = _tierBounds(tier);
        require(minStat >= minAllowed && maxStat <= maxAllowed, "ItemRegistry: stat out of range");

        itemId = ++totalItemTypes;
        itemTypes[itemId] = ItemType({
            name: name,
            category: category,
            tier: tier,
            minStat: minStat,
            maxStat: maxStat,
            creator: msg.sender,
            tradeable: tradeable
        });

        emit ItemTypeRegistered(itemId, name, category, tier);
    }

    function mint(address to, uint256 itemId, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(bytes(itemTypes[itemId].name).length != 0, "ItemRegistry: item missing");
        _mint(to, itemId, amount, "");
    }

    function burn(address from, uint256 itemId, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, itemId, amount);
    }

    function setURI(string calldata newUri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(newUri);
        emit BaseUriUpdated(newUri);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _tierBounds(uint256 tier) internal pure returns (uint256 minAllowed, uint256 maxAllowed) {
        if (tier == 1) return (0, 10);
        if (tier == 2) return (5, 25);
        if (tier == 3) return (10, 50);
        if (tier == 4) return (20, 80);
        return (35, 120);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
