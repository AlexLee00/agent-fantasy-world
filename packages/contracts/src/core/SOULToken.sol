// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title SOULToken — AFW 인게임 통화
 * @notice 공급량 동적 (게임 활동에 따라 발행/소각)
 *         발행: 퀘스트완료, 몬스터처치, 탐험보상
 *         소각: 아이템구매, 스킬강화, 마켓수수료, 부활비용
 */
contract SOULToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 public totalMinted;
    uint256 public totalBurned;

    // 일일 발행 한도 (인플레이션 제어)
    uint256 public dailyMintLimit;
    mapping(uint256 => uint256) public dailyMinted; // day => amount

    event SOULMinted(address indexed to, uint256 amount, string reason, uint256 refId);
    event SOULBurned(address indexed from, uint256 amount, string reason);

    constructor(uint256 _dailyMintLimit) ERC20("SOUL Token", "SOUL") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        dailyMintLimit = _dailyMintLimit;
    }

    function mint(address to, uint256 amount, string calldata reason, uint256 refId)
        external onlyRole(MINTER_ROLE)
    {
        uint256 today = block.timestamp / 1 days;
        require(dailyMinted[today] + amount <= dailyMintLimit, "Daily mint limit exceeded");
        dailyMinted[today] += amount;
        totalMinted += amount;
        _mint(to, amount);
        emit SOULMinted(to, amount, reason, refId);
    }

    function burn(address from, uint256 amount, string calldata reason)
        external onlyRole(BURNER_ROLE)
    {
        _burn(from, amount);
        totalBurned += amount;
        emit SOULBurned(from, amount, reason);
    }

    function setDailyMintLimit(uint256 _limit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        dailyMintLimit = _limit;
    }

    /// @notice 발행/소각 비율 (basis points, 음수 = 디플레이션)
    function getNetInflationBps() external view returns (int256) {
        uint256 supply = totalSupply();
        if (supply == 0) return 0;
        return int256(totalMinted * 10000 / supply) - int256(totalBurned * 10000 / supply);
    }
}
