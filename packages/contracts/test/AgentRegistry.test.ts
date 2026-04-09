import { expect } from "chai";
import { ethers } from "hardhat";
import { deployProxy, seedAgentRegistry } from "./helpers";

describe("AgentRegistry", function () {
  const ORACLE_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ORACLE_ROLE"));
  const defaultPersonality: [number, number, number, number, number] = [70, 30, 50, 80, 60];

  async function setup() {
    const [admin, oracle, observer, stranger] = await ethers.getSigners();
    const { contract: registry } = await deployProxy("AgentRegistry", [admin.address]);
    await seedAgentRegistry(registry);
    await registry.grantRole(ORACLE_ROLE, oracle.address);
    return { registry, admin, oracle, observer, stranger };
  }

  it("creates a warrior agent with registered stats", async function () {
    const { registry, observer } = await setup();
    await registry.connect(observer).createAgent(1, defaultPersonality);

    const agent = await registry.getAgent(1);
    expect(agent.agentId).to.equal(1);
    expect(agent.observer).to.equal(observer.address);
    expect(agent.classId).to.equal(1);
    expect(agent.statusId).to.equal(1);
    expect(agent.zoneId).to.equal(1);
    expect(agent.stats.hp).to.equal(100);
    expect(agent.stats.attack).to.equal(20);
    expect(agent.stats.defense).to.equal(15);
  });

  it("tracks observer agents", async function () {
    const { registry, observer } = await setup();
    await registry.connect(observer).createAgent(1, defaultPersonality);
    await registry.connect(observer).createAgent(2, defaultPersonality);

    const ids = await registry.getObserverAgents(observer.address);
    expect(ids.map((v: bigint) => Number(v))).to.deep.equal([1, 2]);
  });

  it("allows open class and status registration", async function () {
    const { registry, stranger } = await setup();
    const stats = { hp: 90, maxHp: 90, mp: 90, maxMp: 90, attack: 19, defense: 14, speed: 13 };
    await expect(registry.connect(stranger).registerClass("Battlemage", stats, stats))
      .to.emit(registry, "ClassRegistered")
      .withArgs(6, "Battlemage");

    await expect(registry.connect(stranger).registerStatus("SCOUTING", false))
      .to.emit(registry, "StatusRegistered")
      .withArgs(6, "SCOUTING", false);
  });

  it("reverts when class registration is outside balance table", async function () {
    const { registry, stranger } = await setup();
    const invalid = { hp: 200, maxHp: 200, mp: 30, maxMp: 30, attack: 10, defense: 8, speed: 7 };
    await expect(registry.connect(stranger).registerClass("Broken", invalid, invalid))
      .to.be.revertedWith("AgentRegistry: hp out of range");
  });

  it("allows oracle to update agent state and level up", async function () {
    const { registry, oracle, observer } = await setup();
    await registry.connect(observer).createAgent(1, defaultPersonality);

    const newStats = { hp: 80, maxHp: 100, mp: 50, maxMp: 50, attack: 22, defense: 15, speed: 10 };
    await expect(registry.connect(oracle).updateAgentState(1, newStats, 100, 1, 4))
      .to.emit(registry, "AgentLevelUp")
      .withArgs(1, 2);

    const agent = await registry.getAgent(1);
    expect(agent.statusId).to.equal(4);
    expect(agent.level).to.equal(2);
  });

  it("reverts if non-oracle tries to update", async function () {
    const { registry, observer, stranger } = await setup();
    await registry.connect(observer).createAgent(1, defaultPersonality);

    const stats = { hp: 80, maxHp: 100, mp: 50, maxMp: 50, attack: 22, defense: 15, speed: 10 };
    await expect(
      registry.connect(stranger).updateAgentState(1, stats, 50, 1, 1)
    ).to.be.revertedWith("AgentRegistry: not oracle");
  });
});
