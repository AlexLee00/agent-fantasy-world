// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AFWToken — Agent Fantasy World 거버넌스 토큰
 * @notice 총 공급량 1,000,000,000 AFW 고정. 추가 발행 불가.
 *
 * 배분:
 *   40% 노드 채굴 보상  (400,000,000)
 *   25% 커뮤니티 그랜트 (250,000,000)
 *   15% 팀/재단        (150,000,000)
 *   10% 생태계/파트너   (100,000,000)
 *    5% 초기 유동성     ( 50,000,000)
 *    5% 어드바이저      ( 50,000,000)
 */
contract AFWToken is ERC20, Ownable {
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    address public nodeMiningPool;
    address public communityPool;
    address public teamVesting;
    address public ecosystemPool;
    address public liquidityPool;
    address public advisorVesting;

    uint256 public totalBurned;

    event TokensBurned(address indexed from, uint256 amount, string reason);

    constructor(
        address _nodeMiningPool,
        address _communityPool,
        address _teamVesting,
        address _ecosystemPool,
        address _liquidityPool,
        address _advisorVesting
    ) ERC20("Agent Fantasy World", "AFW") Ownable(msg.sender) {
        nodeMiningPool = _nodeMiningPool;
        communityPool  = _communityPool;
        teamVesting    = _teamVesting;
        ecosystemPool  = _ecosystemPool;
        liquidityPool  = _liquidityPool;
        advisorVesting = _advisorVesting;

        _mint(_nodeMiningPool, 400_000_000 * 10 ** 18);
        _mint(_communityPool,  250_000_000 * 10 ** 18);
        _mint(_teamVesting,    150_000_000 * 10 ** 18);
        _mint(_ecosystemPool,  100_000_000 * 10 ** 18);
        _mint(_liquidityPool,   50_000_000 * 10 ** 18);
        _mint(_advisorVesting,  50_000_000 * 10 ** 18);

        require(totalSupply() == TOTAL_SUPPLY, "Supply mismatch");
    }

    /// @notice 프로토콜 수수료 소각 (거버넌스 승인 컨트랙트만)
    function burnForProtocol(uint256 amount, string calldata reason) external onlyOwner {
        _burn(owner(), amount);
        totalBurned += amount;
        emit TokensBurned(owner(), amount, reason);
    }

    /// @notice 고정 공급량 — 추가 mint 영구 불가
    function mint(address, uint256) public pure {
        revert("AFW: fixed supply");
    }
}
