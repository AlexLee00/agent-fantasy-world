import { expect } from "chai";
import { ethers } from "hardhat";
import { deployProxy, seedAgentRegistry } from "./helpers";

describe("CombatResolver", function () {
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  const BURNER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("BURNER_ROLE"));
  const COMBAT_ROLE = ethers.keccak256(ethers.toUtf8Bytes("COMBAT_ROLE"));
  const personality: [number, number, number, number, number] = [70, 30, 50, 80, 60];

  async function setup() {
    const [admin, player] = await ethers.getSigners();
    const { contract: soul } = await deployProxy("SOULToken", [admin.address]);
    const { contract: agentRegistry } = await deployProxy("AgentRegistry", [admin.address]);
    const { contract: monsterRegistry } = await deployProxy("MonsterRegistry", [admin.address]);
    const { contract: treasury } = await deployProxy("EventTreasury", [admin.address, await soul.getAddress()]);
    const { contract: resolver } = await deployProxy("CombatResolver", [
      admin.address,
      await agentRegistry.getAddress(),
      await monsterRegistry.getAddress(),
      await soul.getAddress(),
      await treasury.getAddress(),
    ]);

    await seedAgentRegistry(agentRegistry);
    await agentRegistry.grantRole(COMBAT_ROLE, await resolver.getAddress());
    await monsterRegistry.grantRole(COMBAT_ROLE, await resolver.getAddress());
    await monsterRegistry.setEventTreasury(await treasury.getAddress());
    await treasury.grantRole(COMBAT_ROLE, await monsterRegistry.getAddress());
    await soul.grantRole(MINTER_ROLE, await resolver.getAddress());
    await soul.grantRole(BURNER_ROLE, await resolver.getAddress());

    return { admin, player, soul, agentRegistry, monsterRegistry, treasury, resolver };
  }

  it("lets the agent win and receive all monster SOUL", async function () {
    const { player, soul, agentRegistry, monsterRegistry, resolver } = await setup();

    await agentRegistry.connect(player).createAgent(1, personality);
    await monsterRegistry.registerMonsterType("Slime", 1, 20, 20, 5, 5, 3, 3, 9, 9);
    await monsterRegistry.spawnMonster(1, 1);

    await expect(resolver.resolveCombat(1, 1))
      .to.emit(resolver, "CombatSettled")
      .withArgs(1, 1, true, ethers.parseEther("9"), 34);

    expect(await soul.balanceOf(player.address)).to.equal(ethers.parseEther("9"));
    const monster = await monsterRegistry.getMonster(1);
    expect(monster.alive).to.equal(false);
  });

  it("splits death loot 15% to monster and 15% to treasury and revives the agent", async function () {
    const { admin, player, soul, agentRegistry, monsterRegistry, treasury, resolver } = await setup();

    await soul.grantRole(MINTER_ROLE, admin.address);
    await soul.mint(player.address, ethers.parseEther("100"), "SETUP", 0);
    await agentRegistry.connect(player).createAgent(2, personality);
    await monsterRegistry.registerMonsterType(
      "Abyss Beast",
      4,
      1000,
      1000,
      80,
      80,
      60,
      60,
      300,
      300
    );
    await monsterRegistry.spawnMonster(1, 4);

    await resolver.resolveCombat(1, 1);

    const agent = await agentRegistry.getAgent(1);
    const monster = await monsterRegistry.getMonster(1);
    expect(agent.zoneId).to.equal(1);
    expect(agent.statusId).to.equal(3);
    expect(agent.stats.hp).to.equal(agent.stats.maxHp);
    expect(await soul.balanceOf(player.address)).to.equal(ethers.parseEther("70"));
    expect(await treasury.balance()).to.equal(ethers.parseEther("15"));
    expect(monster.soulBalance).to.equal(ethers.parseEther("315"));
    expect(agent.experience).to.equal(0);
  });
});
