// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "../interfaces/IFreezeAuthority.sol";

/**
 * @title AFWToken — Agent Fantasy World governance token
 * @notice Fixed supply of 1,000,000,000 AFW. Additional minting is permanently disabled.
 */
contract AFWToken is Initializable, ERC20Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    address public nodeMiningPool;
    address public communityPool;
    address public teamVesting;
    address public ecosystemPool;
    address public liquidityPool;
    address public advisorVesting;
    address public governanceDAO;

    uint256 public totalBurned;

    event TokensBurned(address indexed from, uint256 amount, string reason);
    event GovernanceDAOUpdated(address indexed governanceDAO);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _nodeMiningPool,
        address _communityPool,
        address _teamVesting,
        address _ecosystemPool,
        address _liquidityPool,
        address _advisorVesting
    ) external initializer {
        __ERC20_init("Agent Fantasy World", "AFW");
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        nodeMiningPool = _nodeMiningPool;
        communityPool = _communityPool;
        teamVesting = _teamVesting;
        ecosystemPool = _ecosystemPool;
        liquidityPool = _liquidityPool;
        advisorVesting = _advisorVesting;

        _mint(_nodeMiningPool, 400_000_000 * 10 ** 18);
        _mint(_communityPool, 250_000_000 * 10 ** 18);
        _mint(_teamVesting, 150_000_000 * 10 ** 18);
        _mint(_ecosystemPool, 100_000_000 * 10 ** 18);
        _mint(_liquidityPool, 50_000_000 * 10 ** 18);
        _mint(_advisorVesting, 50_000_000 * 10 ** 18);

        require(totalSupply() == TOTAL_SUPPLY, "AFWToken: supply mismatch");
    }

    function burnForProtocol(uint256 amount, string calldata reason) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _burn(msg.sender, amount);
        totalBurned += amount;
        emit TokensBurned(msg.sender, amount, reason);
    }

    function setGovernanceDAO(address dao) external onlyRole(DEFAULT_ADMIN_ROLE) {
        governanceDAO = dao;
        emit GovernanceDAOUpdated(dao);
    }

    function mint(address, uint256) public pure {
        revert("AFW: fixed supply");
    }

    function _update(address from, address to, uint256 value) internal override {
        _enforceWalletNotFrozen(from);
        _enforceWalletNotFrozen(to);
        super._update(from, to, value);
    }

    function _enforceWalletNotFrozen(address account) internal view {
        if (account == address(0) || governanceDAO == address(0)) {
            return;
        }

        require(!IFreezeAuthority(governanceDAO).isWalletFrozen(account), "AFWToken: wallet frozen");
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
