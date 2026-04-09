import { expect } from "chai";
import { ethers } from "hardhat";
import { deployProxy } from "./helpers";

describe("AFWToken", function () {
  const TOTAL = ethers.parseEther("1000000000");

  it("has correct name, symbol, and fixed supply distribution", async function () {
    const [admin, mining, community, team, ecosystem, liquidity, advisor] = await ethers.getSigners();
    const deployment = await deployProxy("AFWToken", [
      admin.address,
      mining.address,
      community.address,
      team.address,
      ecosystem.address,
      liquidity.address,
      advisor.address,
    ]);
    const token = deployment.contract;

    expect(await token.name()).to.equal("Agent Fantasy World");
    expect(await token.symbol()).to.equal("AFW");
    expect(await token.totalSupply()).to.equal(TOTAL);
    expect(await token.balanceOf(mining.address)).to.equal(ethers.parseEther("400000000"));
    expect(await token.balanceOf(community.address)).to.equal(ethers.parseEther("250000000"));
    expect(await token.balanceOf(team.address)).to.equal(ethers.parseEther("150000000"));
    expect(await token.balanceOf(ecosystem.address)).to.equal(ethers.parseEther("100000000"));
    expect(await token.balanceOf(liquidity.address)).to.equal(ethers.parseEther("50000000"));
    expect(await token.balanceOf(advisor.address)).to.equal(ethers.parseEther("50000000"));
  });

  it("reverts on mint attempt", async function () {
    const [admin] = await ethers.getSigners();
    const { contract: token } = await deployProxy("AFWToken", [
      admin.address,
      admin.address,
      admin.address,
      admin.address,
      admin.address,
      admin.address,
      admin.address,
    ]);

    await expect(token.mint(admin.address, 1)).to.be.revertedWith("AFW: fixed supply");
  });

  it("allows admin to burn for protocol", async function () {
    const [admin, mining] = await ethers.getSigners();
    const { contract: token } = await deployProxy("AFWToken", [
      admin.address,
      mining.address,
      admin.address,
      admin.address,
      admin.address,
      admin.address,
      admin.address,
    ]);

    const amt = ethers.parseEther("1000");
    await token.connect(mining).transfer(admin.address, amt);
    await token.burnForProtocol(amt, "protocol fee");

    expect(await token.totalBurned()).to.equal(amt);
    expect(await token.totalSupply()).to.equal(TOTAL - amt);
  });
});
