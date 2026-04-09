// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NodeRewardPool is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

    address public afwToken;

    event RewardsDistributed(uint256 indexed epoch, uint256 recipientCount, uint256 totalAmount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address _afwToken) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        afwToken = _afwToken;
    }

    function distributeRewards(address[] calldata recipients, uint256[] calldata amounts, uint256 epoch)
        external
        onlyRole(DISTRIBUTOR_ROLE)
    {
        require(recipients.length == amounts.length, "NodeRewardPool: length mismatch");

        uint256 totalAmount;
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "NodeRewardPool: recipient required");
            require(amounts[i] > 0, "NodeRewardPool: amount required");
            totalAmount += amounts[i];
            IERC20(afwToken).transfer(recipients[i], amounts[i]);
        }

        emit RewardsDistributed(epoch, recipients.length, totalAmount);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
