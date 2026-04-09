import { expect } from "chai";
import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { deployProxy } from "./helpers";

describe("Distribution suite", function () {
  const DISTRIBUTOR_ROLE = ethers.keccak256(ethers.toUtf8Bytes("DISTRIBUTOR_ROLE"));
  const MONTH = 30 * 24 * 60 * 60;
  const QUARTER = 90 * 24 * 60 * 60;

  it("releases vested tokens in monthly and quarterly steps", async function () {
    const [admin, beneficiary] = await ethers.getSigners();
    const start = BigInt(await time.latest());

    const { contract: afw } = await deployProxy("AFWToken", [
      admin.address,
      admin.address,
      admin.address,
      admin.address,
      admin.address,
      admin.address,
      admin.address,
    ]);

    const { contract: vesting } = await deployProxy("VestingWallet", [
      admin.address,
      await afw.getAddress(),
      beneficiary.address,
      start,
      MONTH,
      48,
      ethers.parseEther("135000000"),
    ]);

    await afw.transfer(await vesting.getAddress(), ethers.parseEther("135000000"));

    await time.increase(MONTH + 1);
    await vesting.release();

    expect(await afw.balanceOf(beneficiary.address)).to.equal(ethers.parseEther("2812500"));

    const { contract: advisorVesting } = await deployProxy("VestingWallet", [
      admin.address,
      await afw.getAddress(),
      beneficiary.address,
      start,
      QUARTER,
      8,
      ethers.parseEther("50000000"),
    ]);

    await afw.transfer(await advisorVesting.getAddress(), ethers.parseEther("50000000"));
    await time.increase(QUARTER + 1);
    await advisorVesting.release();

    expect(await afw.balanceOf(beneficiary.address)).to.equal(
      ethers.parseEther("2812500") + ethers.parseEther("6250000")
    );
  });

  it("distributes node rewards proportionally through the pool", async function () {
    const [admin, nodeA, nodeB] = await ethers.getSigners();
    const { contract: afw } = await deployProxy("AFWToken", [
      admin.address,
      admin.address,
      admin.address,
      admin.address,
      admin.address,
      admin.address,
      admin.address,
    ]);
    const { contract: pool } = await deployProxy("NodeRewardPool", [admin.address, await afw.getAddress()]);

    await afw.transfer(await pool.getAddress(), ethers.parseEther("1000"));
    await pool.grantRole(DISTRIBUTOR_ROLE, admin.address);
    await pool.distributeRewards(
      [nodeA.address, nodeB.address],
      [ethers.parseEther("700"), ethers.parseEther("300")],
      42
    );

    expect(await afw.balanceOf(nodeA.address)).to.equal(ethers.parseEther("700"));
    expect(await afw.balanceOf(nodeB.address)).to.equal(ethers.parseEther("300"));
  });

  it("executes the full AFW distribution plan", async function () {
    const [admin, teamWallet, advisorWallet, lpWallet] = await ethers.getSigners();

    const { contract: afw } = await deployProxy("AFWToken", [
      admin.address,
      admin.address,
      admin.address,
      admin.address,
      admin.address,
      admin.address,
      admin.address,
    ]);

    const now = BigInt(await time.latest());
    const { contract: teamVesting } = await deployProxy("VestingWallet", [
      admin.address,
      await afw.getAddress(),
      teamWallet.address,
      now,
      MONTH,
      48,
      ethers.parseEther("135000000"),
    ]);
    const { contract: advisorVesting } = await deployProxy("VestingWallet", [
      admin.address,
      await afw.getAddress(),
      advisorWallet.address,
      now,
      QUARTER,
      8,
      ethers.parseEther("50000000"),
    ]);
    const { contract: nodePool } = await deployProxy("NodeRewardPool", [admin.address, await afw.getAddress()]);
    const { contract: bountyPool } = await deployProxy("BountyPool", [admin.address, await afw.getAddress()]);
    const { contract: ecosystem } = await deployProxy("EcosystemTreasury", [admin.address, await afw.getAddress(), 1]);
    const { contract: distributor } = await deployProxy("AFWDistributor", [
      admin.address,
      await afw.getAddress(),
      [
        teamWallet.address,
        advisorWallet.address,
        await teamVesting.getAddress(),
        await advisorVesting.getAddress(),
      ],
      [
        await nodePool.getAddress(),
        await bountyPool.getAddress(),
        await ecosystem.getAddress(),
        lpWallet.address,
      ],
    ]);

    await afw.transfer(await distributor.getAddress(), ethers.parseEther("1000000000"));
    await distributor.executeDistribution();

    expect(await afw.balanceOf(teamWallet.address)).to.equal(ethers.parseEther("15000000"));
    expect(await afw.balanceOf(await teamVesting.getAddress())).to.equal(ethers.parseEther("135000000"));
    expect(await afw.balanceOf(await advisorVesting.getAddress())).to.equal(ethers.parseEther("50000000"));
    expect(await afw.balanceOf(await nodePool.getAddress())).to.equal(ethers.parseEther("400000000"));
    expect(await afw.balanceOf(await bountyPool.getAddress())).to.equal(ethers.parseEther("250000000"));
    expect(await afw.balanceOf(await ecosystem.getAddress())).to.equal(ethers.parseEther("100000000"));
    expect(await afw.balanceOf(lpWallet.address)).to.equal(ethers.parseEther("50000000"));
  });
});
