import { expect } from "chai";
import { ethers } from "hardhat";
import { deployProxy } from "./helpers";

describe("GovernanceDAO", function () {
  it("freezes and unfreezes wallets, blocking frozen wallet transfers", async function () {
    const [admin, mining, user, receiver] = await ethers.getSigners();
    const { contract: afw } = await deployProxy("AFWToken", [
      admin.address,
      mining.address,
      admin.address,
      admin.address,
      admin.address,
      admin.address,
      admin.address,
    ]);
    const { contract: nodes } = await deployProxy("NodeRegistry", [admin.address, await afw.getAddress()]);
    const { contract: dao } = await deployProxy("GovernanceDAO", [admin.address, await afw.getAddress(), await nodes.getAddress()]);

    await afw.setGovernanceDAO(await dao.getAddress());
    await afw.connect(mining).transfer(user.address, ethers.parseEther("100"));

    await dao.freezeWallet(user.address);
    await expect(afw.connect(user).transfer(receiver.address, ethers.parseEther("1")))
      .to.be.revertedWith("AFWToken: wallet frozen");

    await dao.unfreezeWallet(user.address);
    await afw.connect(user).transfer(receiver.address, ethers.parseEther("1"));
    expect(await afw.balanceOf(receiver.address)).to.equal(ethers.parseEther("1"));
  });
});
