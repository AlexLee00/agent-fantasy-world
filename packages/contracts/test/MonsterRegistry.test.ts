import { expect } from "chai";
import { ethers } from "hardhat";
import { deployProxy } from "./helpers";

describe("MonsterRegistry", function () {
  const COMBAT_ROLE = ethers.keccak256(ethers.toUtf8Bytes("COMBAT_ROLE"));

  it("registers monster types and spawns stats inside the configured range", async function () {
    const [admin, creator] = await ethers.getSigners();
    const { contract: monsterRegistry } = await deployProxy("MonsterRegistry", [admin.address]);

    await expect(
      monsterRegistry.connect(creator).registerMonsterType("Goblin", 1, 20, 25, 5, 6, 3, 4, 5, 8)
    ).to.emit(monsterRegistry, "MonsterTypeRegistered");

    await monsterRegistry.spawnMonster(1, 1);
    const monster = await monsterRegistry.getMonster(1);
    expect(monster.hp).to.be.gte(20);
    expect(monster.hp).to.be.lte(25);
    expect(monster.soulBalance).to.be.gte(ethers.parseEther("5"));
    expect(monster.soulBalance).to.be.lte(ethers.parseEther("8"));
    expect(monster.alive).to.equal(true);
  });

  it("rejects out-of-spec monster definitions", async function () {
    const [admin, creator] = await ethers.getSigners();
    const { contract: monsterRegistry } = await deployProxy("MonsterRegistry", [admin.address]);

    await expect(
      monsterRegistry.connect(creator).registerMonsterType("Illegal Boss", 1, 10, 25, 5, 6, 3, 4, 5, 8)
    ).to.be.revertedWith("MonsterRegistry: hp out of range");
  });

  it("splits monster victory loot between monster wallet and treasury accounting", async function () {
    const [admin, combat] = await ethers.getSigners();
    const { contract: monsterRegistry } = await deployProxy("MonsterRegistry", [admin.address]);
    const { contract: treasury } = await deployProxy("EventTreasury", [admin.address, ethers.ZeroAddress]);

    await treasury.grantRole(COMBAT_ROLE, await monsterRegistry.getAddress());
    await monsterRegistry.grantRole(COMBAT_ROLE, combat.address);
    await monsterRegistry.setEventTreasury(await treasury.getAddress());
    await monsterRegistry.registerMonsterType("Wraith", 2, 100, 100, 15, 15, 10, 10, 20, 20);
    await monsterRegistry.spawnMonster(1, 2);

    await expect(monsterRegistry.connect(combat).monsterWins(1, ethers.parseEther("100")))
      .to.emit(monsterRegistry, "MonsterLooted")
      .withArgs(1, ethers.parseEther("50"), ethers.parseEther("50"));

    const monster = await monsterRegistry.getMonster(1);
    expect(monster.soulBalance).to.equal(ethers.parseEther("70"));
    expect(await treasury.balance()).to.equal(ethers.parseEther("50"));
  });
});
