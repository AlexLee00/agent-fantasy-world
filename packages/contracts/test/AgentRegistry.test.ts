import { expect } from "chai";
import { ethers } from "hardhat";
import { AgentRegistry } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("AgentRegistry", function () {
  let registry: AgentRegistry;
  let admin: SignerWithAddress;
  let oracle: SignerWithAddress;
  let observer: SignerWithAddress;
  let stranger: SignerWithAddress;

  const ORACLE_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ORACLE_ROLE"));
  // AgentClass: WARRIOR=0, MAGE=1, RANGER=2, HEALER=3, TANK=4
  // AgentStatus: ALIVE=0, DEAD=1, RESTING=2, IN_COMBAT=3, TRAVELING=4
  const WARRIOR = 0;
  const MAGE = 1;
  const TANK = 4;

  const defaultPersonality: [number, number, number, number, number] = [70, 30, 50, 80, 60];

  beforeEach(async function () {
    [admin, oracle, observer, stranger] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory("AgentRegistry");
    registry = await Factory.deploy();
    await registry.grantRole(ORACLE_ROLE, oracle.address);
  });

  describe("Agent creation", function () {
    it("should create a warrior agent with correct stats", async function () {
      await registry.connect(observer).createAgent(WARRIOR, defaultPersonality);
      const agent = await registry.getAgent(1);
      expect(agent.agentId).to.equal(1);
      expect(agent.observer).to.equal(observer.address);
      expect(agent.agentClass).to.equal(WARRIOR);
      expect(agent.status).to.equal(0); // ALIVE
      expect(agent.level).to.equal(1);
      expect(agent.zoneId).to.equal(1); // Lumenveil
      expect(agent.stats.hp).to.equal(100);
      expect(agent.stats.attack).to.equal(20);
      expect(agent.stats.defense).to.equal(15);
    });

    it("should create a tank with high HP stats", async function () {
      await registry.connect(observer).createAgent(TANK, defaultPersonality);
      const agent = await registry.getAgent(1);
      expect(agent.stats.hp).to.equal(150);
      expect(agent.stats.defense).to.equal(25);
    });

    it("should assign personality correctly", async function () {
      await registry.connect(observer).createAgent(MAGE, defaultPersonality);
      const agent = await registry.getAgent(1);
      expect(agent.personality.bravery).to.equal(70);
      expect(agent.personality.curiosity).to.equal(80);
    });

    it("should increment totalAgents", async function () {
      await registry.connect(observer).createAgent(WARRIOR, defaultPersonality);
      await registry.connect(observer).createAgent(MAGE, defaultPersonality);
      expect(await registry.totalAgents()).to.equal(2);
    });

    it("should track observer's agents", async function () {
      await registry.connect(observer).createAgent(WARRIOR, defaultPersonality);
      await registry.connect(observer).createAgent(MAGE, defaultPersonality);
      const ids = await registry.getObserverAgents(observer.address);
      expect(ids.length).to.equal(2);
      expect(ids[0]).to.equal(1);
      expect(ids[1]).to.equal(2);
    });

    it("should emit AgentCreated event", async function () {
      await expect(registry.connect(observer).createAgent(WARRIOR, defaultPersonality))
        .to.emit(registry, "AgentCreated")
        .withArgs(1, observer.address, WARRIOR);
    });
  });

  describe("Oracle state updates", function () {
    beforeEach(async function () {
      await registry.connect(observer).createAgent(WARRIOR, defaultPersonality);
    });

    it("should allow oracle to update agent state", async function () {
      const newStats = { hp: 80, maxHp: 100, mp: 50, maxMp: 50, attack: 22, defense: 15, speed: 10 };
      await registry.connect(oracle).updateAgentState(1, newStats, 50, 1, 0);
      const agent = await registry.getAgent(1);
      expect(agent.stats.hp).to.equal(80);
      expect(agent.stats.attack).to.equal(22);
      expect(agent.experience).to.equal(50);
    });

    it("should revert if non-oracle tries update", async function () {
      const stats = { hp: 80, maxHp: 100, mp: 50, maxMp: 50, attack: 22, defense: 15, speed: 10 };
      await expect(
        registry.connect(stranger).updateAgentState(1, stats, 50, 1, 0)
      ).to.be.revertedWith("AgentRegistry: not oracle");
    });

    it("should trigger level up at 100 exp", async function () {
      const stats = { hp: 100, maxHp: 100, mp: 50, maxMp: 50, attack: 20, defense: 15, speed: 10 };
      await expect(registry.connect(oracle).updateAgentState(1, stats, 100, 1, 0))
        .to.emit(registry, "AgentLevelUp")
        .withArgs(1, 2);
    });

    it("should emit HP_CRITICAL milestone when hp <= 20%", async function () {
      const lowHp = { hp: 15, maxHp: 100, mp: 50, maxMp: 50, attack: 20, defense: 15, speed: 10 };
      await expect(registry.connect(oracle).updateAgentState(1, lowHp, 0, 1, 3))
        .to.emit(registry, "MilestoneTriggered");
    });
  });

  describe("Observer functions", function () {
    beforeEach(async function () {
      await registry.connect(observer).createAgent(WARRIOR, defaultPersonality);
    });

    it("should allow observer to support agent", async function () {
      await expect(registry.connect(observer).supportAgent(1, 42))
        .to.emit(registry, "MilestoneTriggered")
        .withArgs(1, "ITEM_SUPPORT", ethers.AbiCoder.defaultAbiCoder().encode(["uint256"], [42]));
    });

    it("should revert if non-observer tries to support", async function () {
      await expect(
        registry.connect(stranger).supportAgent(1, 42)
      ).to.be.revertedWith("AgentRegistry: not observer");
    });
  });
});
