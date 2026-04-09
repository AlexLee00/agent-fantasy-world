// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "../interfaces/IFreezeAuthority.sol";

/**
 * @title SOULToken — AFW in-game currency
 * @notice Dynamic supply driven by gameplay mint and burn flows. No daily mint limit exists.
 */
contract SOULToken is Initializable, ERC20Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 public totalMinted;
    uint256 public totalBurned;
    address public governanceDAO;

    event SOULMinted(address indexed to, uint256 amount, string reason, uint256 refId);
    event SOULBurned(address indexed from, uint256 amount, string reason);
    event GovernanceDAOUpdated(address indexed governanceDAO);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) external initializer {
        __ERC20_init("SOUL Token", "SOUL");
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function mint(address to, uint256 amount, string calldata reason, uint256 refId)
        external
        onlyRole(MINTER_ROLE)
    {
        totalMinted += amount;
        _mint(to, amount);
        emit SOULMinted(to, amount, reason, refId);
    }

    function burn(address from, uint256 amount, string calldata reason)
        external
        onlyRole(BURNER_ROLE)
    {
        _burn(from, amount);
        totalBurned += amount;
        emit SOULBurned(from, amount, reason);
    }

    function setGovernanceDAO(address dao) external onlyRole(DEFAULT_ADMIN_ROLE) {
        governanceDAO = dao;
        emit GovernanceDAOUpdated(dao);
    }

    function getNetInflationBps() external view returns (int256) {
        uint256 supply = totalSupply();
        if (supply == 0) return 0;
        return int256(totalMinted * 10000 / supply) - int256(totalBurned * 10000 / supply);
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

        require(!IFreezeAuthority(governanceDAO).isWalletFrozen(account), "SOULToken: wallet frozen");
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
