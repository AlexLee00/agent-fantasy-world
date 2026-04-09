// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title EventTreasury
 * @notice Accumulates SOUL from combat deaths and emits world-event thresholds.
 */
contract EventTreasury is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant COMBAT_ROLE = keccak256("COMBAT_ROLE");

    struct EventThreshold {
        uint256 amount;
        string eventType;
        bool triggered;
    }

    uint256 public balance;
    uint256 public totalAccumulated;
    address public soulToken;

    mapping(uint256 => EventThreshold) public thresholds;

    event TreasuryDeposited(uint256 amount, uint256 newBalance);
    event WorldEventTriggered(uint256 indexed thresholdId, string eventType, uint256 amount);
    event RewardsDistributed(uint256 totalReward, uint256 participantCount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address _soulToken) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        soulToken = _soulToken;

        thresholds[1] = EventThreshold({amount: 1_000 * 10 ** 18, eventType: "MINI", triggered: false});
        thresholds[2] = EventThreshold({amount: 5_000 * 10 ** 18, eventType: "ZONE", triggered: false});
        thresholds[3] = EventThreshold({amount: 10_000 * 10 ** 18, eventType: "WORLD_BOSS", triggered: false});
    }

    function deposit(uint256 amount) external onlyRole(COMBAT_ROLE) {
        balance += amount;
        totalAccumulated += amount;
        emit TreasuryDeposited(amount, balance);
        checkAndTriggerEvent();
    }

    function checkAndTriggerEvent() public {
        for (uint256 i = 1; i <= 3; i++) {
            EventThreshold storage threshold = thresholds[i];
            if (!threshold.triggered && balance >= threshold.amount) {
                threshold.triggered = true;
                emit WorldEventTriggered(i, threshold.eventType, threshold.amount);
            }
        }
    }

    function distributeReward(address[] calldata participants) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(participants.length > 0, "EventTreasury: no participants");
        uint256 rewardPool = balance;
        require(rewardPool > 0, "EventTreasury: empty");

        uint256 share = rewardPool / participants.length;
        for (uint256 i = 0; i < participants.length; i++) {
            IERC20(soulToken).transfer(participants[i], share);
        }

        balance = 0;
        thresholds[1].triggered = false;
        thresholds[2].triggered = false;
        thresholds[3].triggered = false;

        emit RewardsDistributed(rewardPool, participants.length);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
