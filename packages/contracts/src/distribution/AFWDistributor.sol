// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AFWDistributor is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    uint256 public constant ONE_TOKEN = 10 ** 18;

    address public afwToken;
    address public teamWallet;
    address public advisorWallet;
    address public teamVestingWallet;
    address public advisorVestingWallet;
    address public nodeRewardPool;
    address public bountyPool;
    address public ecosystemTreasury;
    address public marketplaceLiquidityWallet;
    bool public distributionExecuted;

    event DistributionExecuted(address indexed token);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _afwToken,
        address[4] calldata walletTargets,
        address[4] calldata poolTargets
    ) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        afwToken = _afwToken;
        teamWallet = walletTargets[0];
        advisorWallet = walletTargets[1];
        teamVestingWallet = walletTargets[2];
        advisorVestingWallet = walletTargets[3];
        nodeRewardPool = poolTargets[0];
        bountyPool = poolTargets[1];
        ecosystemTreasury = poolTargets[2];
        marketplaceLiquidityWallet = poolTargets[3];
    }

    function executeDistribution() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!distributionExecuted, "AFWDistributor: already executed");
        distributionExecuted = true;

        IERC20 token = IERC20(afwToken);
        token.transfer(teamWallet, 15_000_000 * ONE_TOKEN);
        token.transfer(teamVestingWallet, 135_000_000 * ONE_TOKEN);
        token.transfer(advisorVestingWallet, 50_000_000 * ONE_TOKEN);
        token.transfer(nodeRewardPool, 400_000_000 * ONE_TOKEN);
        token.transfer(bountyPool, 250_000_000 * ONE_TOKEN);
        token.transfer(ecosystemTreasury, 100_000_000 * ONE_TOKEN);
        token.transfer(marketplaceLiquidityWallet, 50_000_000 * ONE_TOKEN);

        emit DistributionExecuted(afwToken);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
