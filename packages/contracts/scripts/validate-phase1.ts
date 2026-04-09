import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

type Check = { name: string; ok: boolean; detail: string };

async function sendAndWait(txPromise: Promise<any>) {
  const tx = await txPromise;
  return tx.wait();
}

function requireFunction(contract: any, fn: string) {
  return contract.interface.fragments.some((fragment: any) => fragment.type === "function" && fragment.name === fn);
}

async function main() {
  const deploymentsPath = path.join(process.cwd(), "deployments.json");
  const deployments = JSON.parse(fs.readFileSync(deploymentsPath, "utf8"));

  const [rawSigner] = await ethers.getSigners();
  const signer = new ethers.NonceManager(rawSigner);
  const provider = ethers.provider;
  const checks: Check[] = [];

  const afwToken = await ethers.getContractAt("AFWToken", deployments.AFWToken, signer);
  const soulToken = await ethers.getContractAt("SOULToken", deployments.SOULToken, signer);
  const worldMap = await ethers.getContractAt("WorldMap", deployments.WorldMap, signer);
  const agentRegistry = await ethers.getContractAt("AgentRegistry", deployments.AgentRegistry, signer);
  const economyEngine = await ethers.getContractAt("EconomyEngine", deployments.EconomyEngine, signer);
  const questEngine = await ethers.getContractAt("QuestEngine", deployments.QuestEngine, signer);
  const governanceDAO = await ethers.getContractAt("GovernanceDAO", deployments.GovernanceDAO, signer);

  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  const ORACLE_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ORACLE_ROLE"));

  const expectedClasses = ["Warrior", "Mage", "Ranger", "Healer", "Tank"];
  const expectedStatuses = ["ALIVE", "DEAD", "RESTING", "IN_COMBAT", "TRAVELING"];
  const expectedDangerLevels = ["SAFE", "MEDIUM", "DANGER", "EXTREME"];
  const expectedZones = ["Lumenveil", "Graymarch", "Embervault", "Voidreach"];

  const classes: string[] = [];
  for (let i = 1; i <= 5; i++) {
    const entry = await agentRegistry.classRegistry(i);
    classes.push(entry.name);
  }
  checks.push({
    name: "AgentRegistry seeded classes",
    ok: JSON.stringify(classes) === JSON.stringify(expectedClasses),
    detail: classes.join(", "),
  });

  const statuses: string[] = [];
  for (let i = 1; i <= 5; i++) {
    const entry = await agentRegistry.statusRegistry(i);
    statuses.push(entry.name);
  }
  checks.push({
    name: "AgentRegistry seeded statuses",
    ok: JSON.stringify(statuses) === JSON.stringify(expectedStatuses),
    detail: statuses.join(", "),
  });

  const newClassStats = {
    hp: 90,
    maxHp: 90,
    mp: 80,
    maxMp: 80,
    attack: 19,
    defense: 14,
    speed: 13,
  };
  await sendAndWait(agentRegistry.registerClass("VerifierClass", newClassStats, newClassStats));
  const totalClasses = Number(await agentRegistry.totalClasses());
  const verifierClass = await agentRegistry.classRegistry(totalClasses);
  checks.push({
    name: "AgentRegistry registerClass()",
    ok: verifierClass.name === "VerifierClass",
    detail: `registered classId=${totalClasses} name=${verifierClass.name}`,
  });

  await sendAndWait(agentRegistry.registerStatus("VERIFYING", false));
  const totalStatuses = Number(await agentRegistry.totalStatuses());
  const verifierStatus = await agentRegistry.statusRegistry(totalStatuses);
  checks.push({
    name: "AgentRegistry registerStatus()",
    ok: verifierStatus.name === "VERIFYING",
    detail: `registered statusId=${totalStatuses} name=${verifierStatus.name}`,
  });

  const dangerLevels: string[] = [];
  for (let i = 1; i <= 4; i++) {
    const entry = await worldMap.dangerLevels(i);
    dangerLevels.push(entry.name);
  }
  checks.push({
    name: "WorldMap seeded danger levels",
    ok: JSON.stringify(dangerLevels) === JSON.stringify(expectedDangerLevels),
    detail: dangerLevels.join(", "),
  });

  const zones: string[] = [];
  for (let i = 1; i <= 4; i++) {
    const zone = await worldMap.getZone(i);
    zones.push(zone.name);
  }
  checks.push({
    name: "WorldMap seeded zones",
    ok: JSON.stringify(zones) === JSON.stringify(expectedZones),
    detail: zones.join(", "),
  });

  await sendAndWait(worldMap.registerDangerLevel("CHAOTIC", 60, 99));
  const totalDangerLevels = Number(await worldMap.totalDangerLevels());
  const chaotic = await worldMap.dangerLevels(totalDangerLevels);
  checks.push({
    name: "WorldMap registerDangerLevel()",
    ok: chaotic.name === "CHAOTIC",
    detail: `registered dangerId=${totalDangerLevels} name=${chaotic.name}`,
  });

  checks.push({
    name: "SOULToken dailyMintLimit removed",
    ok: !requireFunction(soulToken, "dailyMintLimit"),
    detail: `dailyMintLimit present=${requireFunction(soulToken, "dailyMintLimit")}`,
  });

  if (!(await soulToken.hasRole(MINTER_ROLE, await signer.getAddress()))) {
    await sendAndWait(soulToken.grantRole(MINTER_ROLE, await signer.getAddress()));
  }
  const soulBefore = await soulToken.balanceOf(await signer.getAddress());
  const mintAmountA = ethers.parseEther("1500000");
  const mintAmountB = ethers.parseEther("1750000");
  await sendAndWait(soulToken.mint(await signer.getAddress(), mintAmountA, "phase1_validate", 1));
  await sendAndWait(soulToken.mint(await signer.getAddress(), mintAmountB, "phase1_validate", 2));
  const soulAfter = await soulToken.balanceOf(await signer.getAddress());
  checks.push({
    name: "SOULToken unlimited mint",
    ok: soulAfter - soulBefore === mintAmountA + mintAmountB,
    detail: `minted=${ethers.formatEther(soulAfter - soulBefore)} SOUL`,
  });

  checks.push({
    name: "EconomyEngine burnForRevival removed",
    ok: !requireFunction(economyEngine, "burnForRevival"),
    detail: `burnForRevival present=${requireFunction(economyEngine, "burnForRevival")}`,
  });
  checks.push({
    name: "EconomyEngine processDeath exists",
    ok: requireFunction(economyEngine, "processDeath"),
    detail: `processDeath present=${requireFunction(economyEngine, "processDeath")}`,
  });

  const agentWallet = ethers.Wallet.createRandom().address;
  const monsterWallet = ethers.Wallet.createRandom().address;
  const treasuryAddress = await signer.getAddress();
  const treasuryBefore = await soulToken.balanceOf(treasuryAddress);
  await sendAndWait(soulToken.mint(agentWallet, ethers.parseEther("1000"), "phase1_validate_setup", 3));
  await sendAndWait(economyEngine.processDeath(agentWallet, monsterWallet, 1000, 999));
  const agentAfterDeath = await soulToken.balanceOf(agentWallet);
  const monsterAfterDeath = await soulToken.balanceOf(monsterWallet);
  const treasuryAfter = await soulToken.balanceOf(treasuryAddress);
  checks.push({
    name: "EconomyEngine processDeath 30% loot split",
    ok:
      agentAfterDeath === ethers.parseEther("700") &&
      monsterAfterDeath === ethers.parseEther("150") &&
      treasuryAfter - treasuryBefore === ethers.parseEther("150"),
    detail: `agent=${ethers.formatEther(agentAfterDeath)} monster=${ethers.formatEther(monsterAfterDeath)} treasuryDelta=${ethers.formatEther(treasuryAfter - treasuryBefore)}`,
  });

  checks.push({
    name: "QuestEngine royalty split logic exists",
    ok: requireFunction(questEngine, "creatorEarned") && requireFunction(questEngine, "registerQuest"),
    detail: `creatorEarned getter=${requireFunction(questEngine, "creatorEarned")}`,
  });

  const observer = ethers.Wallet.createRandom().connect(provider);
  await sendAndWait(signer.sendTransaction({ to: observer.address, value: ethers.parseEther("0.001") }));

  if (!(await questEngine.hasRole(ORACLE_ROLE, await signer.getAddress()))) {
    await sendAndWait(questEngine.grantRole(ORACLE_ROLE, await signer.getAddress()));
  }

  const observerRegistry = agentRegistry.connect(observer);
  const totalAgentsBefore = Number(await agentRegistry.totalAgents());
  await sendAndWait(observerRegistry.createAgent(1, [70, 30, 50, 80, 60]));
  const agentId = totalAgentsBefore + 1;
  const creatorBefore = await soulToken.balanceOf(await signer.getAddress());
  const observerBefore = await soulToken.balanceOf(observer.address);
  const creatorEarnedBefore = await questEngine.creatorEarned(await signer.getAddress());

  const condition = { questType: 0, targetId: 501, targetCount: 1, timeLimitSec: 0 };
  const reward = { soulAmount: ethers.parseEther("100"), expAmount: 10, afwAmount: 0, itemIds: [] };
  const totalQuestsBefore = Number(await questEngine.totalQuests());
  await sendAndWait(questEngine.registerQuest("Phase1 Validation Quest", "Verify royalty flow", 1, 1, condition, reward));
  const questId = totalQuestsBefore + 1;
  await sendAndWait(questEngine.startQuest(agentId, questId));
  await sendAndWait(questEngine.updateProgress(agentId, 1, false));

  const creatorAfter = await soulToken.balanceOf(await signer.getAddress());
  const observerAfter = await soulToken.balanceOf(observer.address);
  const creatorEarnedAfter = await questEngine.creatorEarned(await signer.getAddress());
  checks.push({
    name: "QuestEngine 95/5 creator royalty",
    ok:
      observerAfter - observerBefore === ethers.parseEther("95") &&
      creatorAfter - creatorBefore >= ethers.parseEther("5") &&
      creatorEarnedAfter - creatorEarnedBefore === ethers.parseEther("5"),
    detail: `observerDelta=${ethers.formatEther(observerAfter - observerBefore)} creatorEarnedDelta=${ethers.formatEther(creatorEarnedAfter - creatorEarnedBefore)}`,
  });

  checks.push({
    name: "GovernanceDAO freezeWallet()/unfreezeWallet() exist",
    ok: requireFunction(governanceDAO, "freezeWallet") && requireFunction(governanceDAO, "unfreezeWallet"),
    detail: `freeze=${requireFunction(governanceDAO, "freezeWallet")} unfreeze=${requireFunction(governanceDAO, "unfreezeWallet")}`,
  });

  const outsider = ethers.Wallet.createRandom().connect(provider);
  await sendAndWait(signer.sendTransaction({ to: outsider.address, value: ethers.parseEther("0.001") }));
  let outsiderReverted = false;
  try {
    await sendAndWait(governanceDAO.connect(outsider).freezeWallet(observer.address));
  } catch {
    outsiderReverted = true;
  }

  await sendAndWait(governanceDAO.freezeWallet(observer.address));
  const frozen = await governanceDAO.isWalletFrozen(observer.address);
  await sendAndWait(governanceDAO.unfreezeWallet(observer.address));
  const unfrozen = await governanceDAO.isWalletFrozen(observer.address);
  checks.push({
    name: "GovernanceDAO admin gating and wallet freeze flow",
    ok: outsiderReverted && frozen === true && unfrozen === false,
    detail: `outsiderReverted=${outsiderReverted} frozen=${frozen} unfrozen=${unfrozen}`,
  });

  const contractFiles = [
    "src/core/AFWToken.sol",
    "src/core/SOULToken.sol",
    "src/game/AgentRegistry.sol",
    "src/world/WorldMap.sol",
    "src/economy/EconomyEngine.sol",
    "src/game/QuestEngine.sol",
    "src/node/NodeRegistry.sol",
    "src/node/OracleGateway.sol",
    "src/governance/GovernanceDAO.sol",
  ];

  for (const relativeFile of contractFiles) {
    const source = fs.readFileSync(path.join(process.cwd(), relativeFile), "utf8");
    checks.push({
      name: `${relativeFile} UUPS inheritance`,
      ok: source.includes("UUPSUpgradeable"),
      detail: "contains UUPSUpgradeable",
    });
    checks.push({
      name: `${relativeFile} _disableInitializers`,
      ok: source.includes("_disableInitializers();"),
      detail: "constructor disables initializers",
    });
    checks.push({
      name: `${relativeFile} __gap[50]`,
      ok: source.includes("uint256[50] private __gap;"),
      detail: "contains 50-slot storage gap",
    });
    checks.push({
      name: `${relativeFile} _authorizeUpgrade onlyRole`,
      ok: source.includes("_authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE)"),
      detail: "authorizeUpgrade uses DEFAULT_ADMIN_ROLE",
    });
  }

  const failed = checks.filter((check) => !check.ok);
  console.log(JSON.stringify({ checks, failedCount: failed.length }, null, 2));

  if (failed.length > 0) {
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
