// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IEconomyEngine.sol";

/**
 * @title Marketplace
 * @notice Minimal P2P marketplace with SOUL-denominated settlement and 2% burn.
 */
contract Marketplace is
    Initializable,
    AccessControlUpgradeable,
    ERC1155Holder,
    UUPSUpgradeable
{
    struct Order {
        address seller;
        uint256 itemId;
        uint256 amount;
        uint256 priceInSOUL;
        bool active;
        uint256 createdAt;
    }

    mapping(uint256 => Order) public orders;
    uint256 public totalOrders;

    address public soulToken;
    address public afwToken;
    address public itemRegistry;
    address public economyEngine;

    event OrderCreated(uint256 indexed orderId, address indexed seller, uint256 itemId, uint256 amount, uint256 priceInSOUL);
    event OrderCancelled(uint256 indexed orderId);
    event OrderFilled(uint256 indexed orderId, address indexed buyer, uint256 feeBurned);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _soulToken,
        address _afwToken,
        address _itemRegistry,
        address _economyEngine
    ) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        soulToken = _soulToken;
        afwToken = _afwToken;
        itemRegistry = _itemRegistry;
        economyEngine = _economyEngine;
    }

    function createOrder(uint256 itemId, uint256 amount, uint256 priceInSOUL) external returns (uint256 orderId) {
        require(amount > 0, "Marketplace: invalid amount");
        require(priceInSOUL > 0, "Marketplace: invalid price");

        orderId = ++totalOrders;
        orders[orderId] = Order({
            seller: msg.sender,
            itemId: itemId,
            amount: amount,
            priceInSOUL: priceInSOUL,
            active: true,
            createdAt: block.timestamp
        });

        if (itemId == 0) {
            IERC20(afwToken).transferFrom(msg.sender, address(this), amount);
        } else {
            IERC1155(itemRegistry).safeTransferFrom(msg.sender, address(this), itemId, amount, "");
        }

        emit OrderCreated(orderId, msg.sender, itemId, amount, priceInSOUL);
    }

    function cancelOrder(uint256 orderId) external {
        Order storage order = orders[orderId];
        require(order.active, "Marketplace: inactive");
        require(order.seller == msg.sender, "Marketplace: not seller");
        order.active = false;

        if (order.itemId == 0) {
            IERC20(afwToken).transfer(order.seller, order.amount);
        } else {
            IERC1155(itemRegistry).safeTransferFrom(address(this), order.seller, order.itemId, order.amount, "");
        }

        emit OrderCancelled(orderId);
    }

    function fillOrder(uint256 orderId) external {
        Order storage order = orders[orderId];
        require(order.active, "Marketplace: inactive");
        require(order.itemId != 0, "Marketplace: use fillOrderAFW");
        order.active = false;

        uint256 fee = order.priceInSOUL * 200 / 10000;
        uint256 sellerProceeds = order.priceInSOUL - fee;

        IERC20(soulToken).transferFrom(msg.sender, order.seller, sellerProceeds);
        IEconomyEngine(economyEngine).burnMarketFee(msg.sender, order.priceInSOUL);
        IERC1155(itemRegistry).safeTransferFrom(address(this), msg.sender, order.itemId, order.amount, "");

        emit OrderFilled(orderId, msg.sender, fee);
    }

    function fillOrderAFW(uint256 orderId) external {
        Order storage order = orders[orderId];
        require(order.active, "Marketplace: inactive");
        require(order.itemId == 0, "Marketplace: not AFW order");
        order.active = false;

        uint256 fee = order.priceInSOUL * 200 / 10000;
        uint256 sellerProceeds = order.priceInSOUL - fee;

        IERC20(soulToken).transferFrom(msg.sender, order.seller, sellerProceeds);
        IEconomyEngine(economyEngine).burnMarketFee(msg.sender, order.priceInSOUL);
        IERC20(afwToken).transfer(msg.sender, order.amount);

        emit OrderFilled(orderId, msg.sender, fee);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable, ERC1155Holder)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
