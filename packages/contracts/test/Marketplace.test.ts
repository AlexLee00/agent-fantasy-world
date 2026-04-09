import { expect } from "chai";
import { ethers } from "hardhat";
import { deployProxy } from "./helpers";

describe("Marketplace", function () {
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  const BURNER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("BURNER_ROLE"));
  const MARKET_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MARKET_ROLE"));

  it("creates, cancels, and fills item orders with a 2% SOUL burn", async function () {
    const [admin, seller, buyer] = await ethers.getSigners();
    const { contract: afw } = await deployProxy("AFWToken", [
      admin.address,
      admin.address,
      admin.address,
      admin.address,
      admin.address,
      admin.address,
      admin.address,
    ]);
    const { contract: soul } = await deployProxy("SOULToken", [admin.address]);
    const { contract: economyEngine } = await deployProxy("EconomyEngine", [admin.address, await soul.getAddress(), admin.address]);
    const { contract: itemRegistry } = await deployProxy("ItemRegistry", [admin.address, "ipfs://items/{id}.json"]);
    const { contract: marketplace } = await deployProxy("Marketplace", [
      admin.address,
      await soul.getAddress(),
      await afw.getAddress(),
      await itemRegistry.getAddress(),
      await economyEngine.getAddress(),
    ]);

    await soul.grantRole(MINTER_ROLE, admin.address);
    await soul.grantRole(BURNER_ROLE, await economyEngine.getAddress());
    await economyEngine.grantRole(MARKET_ROLE, await marketplace.getAddress());
    await itemRegistry.registerItemType("Leather Armor", "ARMOR", 2, 10, 25, true);
    await itemRegistry.grantRole(MINTER_ROLE, admin.address);
    await itemRegistry.mint(seller.address, 1, 1);
    await soul.mint(buyer.address, ethers.parseEther("100"), "SETUP", 0);

    await itemRegistry.connect(seller).setApprovalForAll(await marketplace.getAddress(), true);
    await marketplace.connect(seller).createOrder(1, 1, ethers.parseEther("100"));
    await marketplace.connect(seller).cancelOrder(1);

    await marketplace.connect(seller).createOrder(1, 1, ethers.parseEther("100"));
    await soul.connect(buyer).approve(await marketplace.getAddress(), ethers.parseEther("98"));
    await soul.connect(buyer).approve(await economyEngine.getAddress(), ethers.parseEther("2"));
    await marketplace.connect(buyer).fillOrder(2);

    expect(await itemRegistry.balanceOf(buyer.address, 1)).to.equal(1);
    expect(await soul.balanceOf(seller.address)).to.equal(ethers.parseEther("98"));
    expect(await soul.totalBurned()).to.equal(ethers.parseEther("2"));
  });
});
