import { expect } from "chai";
import { ethers } from "hardhat";
import { deployProxy, seedAgentRegistry } from "./helpers";

describe("QuestEngine", function () {
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  const BURNER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("BURNER_ROLE"));
  const QUEST_ROLE = ethers.keccak256(ethers.toUtf8Bytes("QUEST_ROLE"));
  const ORACLE_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ORACLE_ROLE"));
  const personality: [number, number, number, number, number] = [70, 30, 50, 80, 60];

  it("pays 95% to agent observer and 5% to creator on completion", async function () {
    const [admin, creator, oracle, observer, treasury] = await ethers.getSigners();
    const { contract: soul } = await deployProxy("SOULToken", [admin.address]);
    const { contract: economy } = await deployProxy("EconomyEngine", [admin.address, await soul.getAddress(), treasury.address]);
    const { contract: registry } = await deployProxy("AgentRegistry", [admin.address]);
    const { contract: quests } = await deployProxy("QuestEngine", [admin.address, await registry.getAddress(), await economy.getAddress()]);

    await seedAgentRegistry(registry);
    await registry.connect(observer).createAgent(1, personality);

    await soul.grantRole(MINTER_ROLE, await economy.getAddress());
    await soul.grantRole(BURNER_ROLE, await economy.getAddress());
    await economy.grantRole(QUEST_ROLE, await quests.getAddress());
    await quests.grantRole(ORACLE_ROLE, oracle.address);

    const condition = { questType: 0, targetId: 99, targetCount: 1, timeLimitSec: 0 };
    const reward = { soulAmount: ethers.parseEther("100"), expAmount: 10, afwAmount: 0, itemIds: [] };
    await quests.connect(creator).registerQuest("First Hunt", "Slay one goblin", 1, 1, condition, reward);
    await quests.connect(oracle).startQuest(1, 1);
    await quests.connect(oracle).updateProgress(1, 1, false);

    expect(await soul.balanceOf(observer.address)).to.equal(ethers.parseEther("95"));
    expect(await soul.balanceOf(creator.address)).to.equal(ethers.parseEther("5"));
    expect(await quests.creatorEarned(creator.address)).to.equal(ethers.parseEther("5"));
  });
});
