import { expect } from "chai";
import { ethers } from "hardhat";
import { deployProxy } from "./helpers";

describe("UUPS upgrades", function () {
  it("preserves state when upgrading AFWToken V1 to V2", async function () {
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
    expect(await token.balanceOf(mining.address)).to.equal(ethers.parseEther("400000000"));

    const v2Factory = await ethers.getContractFactory("AFWTokenV2Mock");
    const v2Implementation = await v2Factory.deploy();
    await v2Implementation.waitForDeployment();

    await token.upgradeToAndCall(await v2Implementation.getAddress(), "0x");
    const upgraded = await ethers.getContractAt("AFWTokenV2Mock", await token.getAddress());

    expect(await upgraded.balanceOf(mining.address)).to.equal(ethers.parseEther("400000000"));
    expect(await upgraded.communityPool()).to.equal(community.address);
    expect(await upgraded.version()).to.equal(2);
  });
});
