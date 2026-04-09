// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title VestingWallet
 * @notice Step-based vesting wallet for AFW allocations with UUPS upgradeability.
 */
contract VestingWallet is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    address public token;
    address public beneficiary;
    uint64 public startTimestamp;
    uint64 public stepDuration;
    uint64 public totalSteps;
    uint256 public totalAllocation;
    uint256 public released;

    event TokensReleased(address indexed beneficiary, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _token,
        address _beneficiary,
        uint64 _startTimestamp,
        uint64 _stepDuration,
        uint64 _totalSteps,
        uint256 _totalAllocation
    ) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        require(_beneficiary != address(0), "VestingWallet: beneficiary required");
        require(_token != address(0), "VestingWallet: token required");
        require(_stepDuration > 0, "VestingWallet: step duration required");
        require(_totalSteps > 0, "VestingWallet: total steps required");

        token = _token;
        beneficiary = _beneficiary;
        startTimestamp = _startTimestamp;
        stepDuration = _stepDuration;
        totalSteps = _totalSteps;
        totalAllocation = _totalAllocation;
    }

    function vestedAmount(uint64 timestamp) public view returns (uint256) {
        if (timestamp <= startTimestamp) {
            return 0;
        }

        uint256 elapsed = uint256(timestamp - startTimestamp);
        uint256 stepsElapsed = elapsed / stepDuration;

        if (stepsElapsed >= totalSteps) {
            return totalAllocation;
        }

        return totalAllocation * stepsElapsed / totalSteps;
    }

    function releasable() public view returns (uint256) {
        uint256 vested = vestedAmount(uint64(block.timestamp));
        return vested > released ? vested - released : 0;
    }

    function release() external returns (uint256 amount) {
        amount = releasable();
        require(amount > 0, "VestingWallet: nothing releasable");
        released += amount;
        IERC20(token).transfer(beneficiary, amount);
        emit TokensReleased(beneficiary, amount);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
