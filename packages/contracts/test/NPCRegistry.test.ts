import { expect } from "chai";
import { ethers } from "hardhat";
import { deployProxy } from "./helpers";

describe("NPCRegistry", function () {
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));

  it("exposes the hardcoded base price anchors", async function () {
    const [admin] = await ethers.getSigners();
    const { contract: itemRegistry } = await deployProxy("ItemRegistry", [admin.address, "ipfs://items/{id}.json"]);
    const { contract: soul } = await deployProxy("SOULToken", [admin.address]);
    const { contract: npcRegistry } = await deployProxy("NPCRegistry", [admin.address, await itemRegistry.getAddress(), await soul.getAddress()]);

    expect(await npcRegistry.getBasePriceAnchor(1)).to.equal(ethers.parseEther("5"));
    expect(await npcRegistry.getBasePriceAnchor(2)).to.equal(ethers.parseEther("10"));
    expect(await npcRegistry.getBasePriceAnchor(6)).to.equal(ethers.parseEther("30"));
  });

  it("handles npc sales and supply-chain purchases", async function () {
    const [admin, buyer] = await ethers.getSigners();
    const { contract: itemRegistry } = await deployProxy("ItemRegistry", [admin.address, "ipfs://items/{id}.json"]);
    const { contract: soul } = await deployProxy("SOULToken", [admin.address]);
    const { contract: npcRegistry } = await deployProxy("NPCRegistry", [admin.address, await itemRegistry.getAddress(), await soul.getAddress()]);

    await itemRegistry.registerItemType("Basic Potion", "POTION", 1, 0, 5, true);
    await itemRegistry.grantRole(MINTER_ROLE, await npcRegistry.getAddress());
    await soul.grantRole(MINTER_ROLE, admin.address);
    await soul.mint(buyer.address, ethers.parseEther("100"), "SETUP", 0);

    await npcRegistry.registerNPCType("Mira", "SHOP", 1);
    await npcRegistry.spawnNPC(1, 1, ethers.parseEther("20"));
    await npcRegistry.setPrice(1, 1, ethers.parseEther("10"));

    await soul.connect(buyer).approve(await npcRegistry.getAddress(), ethers.parseEther("10"));
    await npcRegistry.connect(buyer).buyFromNPC(1, 1);

    expect(await itemRegistry.balanceOf(buyer.address, 1)).to.equal(1);
    const npc = await npcRegistry.npcs(1);
    expect(npc.soulBalance).to.equal(ethers.parseEther("30"));

    await npcRegistry.spawnNPC(1, 1, ethers.parseEther("50"));
    await npcRegistry.npcBuyFromNPC(2, 1, 1);
    const buyerNpc = await npcRegistry.npcs(2);
    const sellerNpc = await npcRegistry.npcs(1);
    expect(buyerNpc.soulBalance).to.equal(ethers.parseEther("40"));
    expect(sellerNpc.soulBalance).to.equal(ethers.parseEther("40"));
  });
});
