import { expect } from "chai";
import { ethers } from "hardhat";
import { deployProxy } from "./helpers";

describe("ItemRegistry", function () {
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  const BURNER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("BURNER_ROLE"));

  it("allows open item registration within tier bounds", async function () {
    const [admin, creator] = await ethers.getSigners();
    const { contract: itemRegistry } = await deployProxy("ItemRegistry", [admin.address, "ipfs://items/{id}.json"]);

    await expect(itemRegistry.connect(creator).registerItemType("Iron Sword", "WEAPON", 2, 10, 20, true))
      .to.emit(itemRegistry, "ItemTypeRegistered")
      .withArgs(1, "Iron Sword", "WEAPON", 2);

    const itemType = await itemRegistry.itemTypes(1);
    expect(itemType.creator).to.equal(creator.address);
    expect(itemType.tradeable).to.equal(true);
  });

  it("rejects out-of-spec item registration", async function () {
    const [admin, creator] = await ethers.getSigners();
    const { contract: itemRegistry } = await deployProxy("ItemRegistry", [admin.address, "ipfs://items/{id}.json"]);

    await expect(
      itemRegistry.connect(creator).registerItemType("Broken Blade", "WEAPON", 1, 11, 15, true)
    ).to.be.revertedWith("ItemRegistry: stat out of range");
  });

  it("allows authorized mint and burn", async function () {
    const [admin, minter, burner, player] = await ethers.getSigners();
    const { contract: itemRegistry } = await deployProxy("ItemRegistry", [admin.address, "ipfs://items/{id}.json"]);

    await itemRegistry.registerItemType("Health Potion", "POTION", 1, 0, 5, true);
    await itemRegistry.grantRole(MINTER_ROLE, minter.address);
    await itemRegistry.grantRole(BURNER_ROLE, burner.address);

    await itemRegistry.connect(minter).mint(player.address, 1, 3);
    expect(await itemRegistry.balanceOf(player.address, 1)).to.equal(3);

    await itemRegistry.connect(burner).burn(player.address, 1, 2);
    expect(await itemRegistry.balanceOf(player.address, 1)).to.equal(1);
  });
});
