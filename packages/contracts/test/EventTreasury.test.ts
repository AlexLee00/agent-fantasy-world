import { expect } from "chai";
import { ethers } from "hardhat";
import { deployProxy } from "./helpers";

describe("EventTreasury", function () {
  const COMBAT_ROLE = ethers.keccak256(ethers.toUtf8Bytes("COMBAT_ROLE"));
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));

  it("tracks deposits and triggers thresholds", async function () {
    const [admin, combat] = await ethers.getSigners();
    const { contract: soul } = await deployProxy("SOULToken", [admin.address]);
    const { contract: treasury } = await deployProxy("EventTreasury", [admin.address, await soul.getAddress()]);

    await treasury.grantRole(COMBAT_ROLE, combat.address);
    await expect(treasury.connect(combat).deposit(ethers.parseEther("1000")))
      .to.emit(treasury, "WorldEventTriggered")
      .withArgs(1, "MINI", ethers.parseEther("1000"));

    expect(await treasury.balance()).to.equal(ethers.parseEther("1000"));
    expect((await treasury.thresholds(1)).triggered).to.equal(true);
  });

  it("distributes rewards and resets cycle state", async function () {
    const [admin, alice, bob] = await ethers.getSigners();
    const { contract: soul } = await deployProxy("SOULToken", [admin.address]);
    const { contract: treasury } = await deployProxy("EventTreasury", [admin.address, await soul.getAddress()]);

    await soul.grantRole(MINTER_ROLE, admin.address);
    await treasury.grantRole(COMBAT_ROLE, admin.address);
    await soul.mint(await treasury.getAddress(), ethers.parseEther("200"), "TREASURY", 0);
    await treasury.deposit(ethers.parseEther("200"));

    await treasury.distributeReward([alice.address, bob.address]);

    expect(await soul.balanceOf(alice.address)).to.equal(ethers.parseEther("100"));
    expect(await soul.balanceOf(bob.address)).to.equal(ethers.parseEther("100"));
    expect(await treasury.balance()).to.equal(0);
    expect((await treasury.thresholds(1)).triggered).to.equal(false);
  });
});
