import { ethers } from "hardhat";

type ProxyDeployment<T> = {
  implementation: string;
  proxy: string;
  contract: T;
};

type DeploymentsFile = {
  network: string;
  AFWToken: string;
  SOULToken: string;
  WorldMap: string;
  AgentRegistry: string;
  NodeRegistry: string;
  OracleGateway: string;
  EconomyEngine: string;
  QuestEngine: string;
  GovernanceDAO: string;
  ItemRegistry?: string;
  MonsterRegistry?: string;
  NPCRegistry?: string;
  EventTreasury?: string;
  CombatResolver?: string;
  Marketplace?: string;
  implementations: Record<string, string>;
};

async function sendAndWait(txPromise: Promise<any>) {
  const tx = await txPromise;
  await tx.wait();
}

async function getFeeOverrides() {
  const feeData = await ethers.provider.getFeeData();

  if (feeData.maxFeePerGas && feeData.maxPriorityFeePerGas) {
    return {
      maxFeePerGas: feeData.maxFeePerGas * 3n,
      maxPriorityFeePerGas: feeData.maxPriorityFeePerGas * 3n,
    };
  }

  if (feeData.gasPrice) {
    return {
      gasPrice: feeData.gasPrice * 3n,
    };
  }

  return {};
}

async function deployUUPSProxy<T = any>(contractName: string, initArgs: any[], signer: any): Promise<ProxyDeployment<T>> {
  const factory = await ethers.getContractFactory(contractName, signer);
  const feeOverrides = await getFeeOverrides();
  const implementation = await factory.deploy(feeOverrides);
  await implementation.waitForDeployment();

  const proxyFactory = await ethers.getContractFactory("AFWUUPSProxy", signer);
  const initData = factory.interface.encodeFunctionData("initialize", initArgs);
  const proxy = await proxyFactory.deploy(await implementation.getAddress(), initData, feeOverrides);
  await proxy.waitForDeployment();

  return {
    implementation: await implementation.getAddress(),
    proxy: await proxy.getAddress(),
    contract: await ethers.getContractAt(contractName, await proxy.getAddress(), signer) as T,
  };
}

async function main() {
  const fs = await import("fs");
  const deploymentsPath = "deployments.json";
  const raw = fs.readFileSync(deploymentsPath, "utf8");
  const existing = JSON.parse(raw) as DeploymentsFile;

  const [deployer] = await ethers.getSigners();
  const signer = new ethers.NonceManager(deployer);
  const admin = process.env.MULTISIG_ADMIN_ADDRESS || deployer.address;
  const feeOverrides = await getFeeOverrides();

  console.log("Phase 3 deployer:", deployer.address);
  console.log("Admin:", admin);
  console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");
  console.log("Using existing proxies:", {
    AFWToken: existing.AFWToken,
    SOULToken: existing.SOULToken,
    AgentRegistry: existing.AgentRegistry,
    EconomyEngine: existing.EconomyEngine,
  });
  console.log("Fee overrides:", feeOverrides);

  console.log("\n1/6 Deploying ItemRegistry proxy...");
  const itemRegistry = await deployUUPSProxy("ItemRegistry", [admin, "https://afw.game/items/{id}.json"], signer);
  console.log("  ✅ ItemRegistry:", itemRegistry.proxy);

  console.log("2/6 Deploying MonsterRegistry proxy...");
  const monsterRegistry = await deployUUPSProxy("MonsterRegistry", [admin], signer);
  console.log("  ✅ MonsterRegistry:", monsterRegistry.proxy);

  console.log("3/6 Deploying NPCRegistry proxy...");
  const npcRegistry = await deployUUPSProxy("NPCRegistry", [admin, itemRegistry.proxy, existing.SOULToken], signer);
  console.log("  ✅ NPCRegistry:", npcRegistry.proxy);

  console.log("4/6 Deploying EventTreasury proxy...");
  const eventTreasury = await deployUUPSProxy("EventTreasury", [admin, existing.SOULToken], signer);
  console.log("  ✅ EventTreasury:", eventTreasury.proxy);

  console.log("5/6 Deploying CombatResolver proxy...");
  const combatResolver = await deployUUPSProxy(
    "CombatResolver",
    [admin, existing.AgentRegistry, monsterRegistry.proxy, existing.SOULToken, eventTreasury.proxy],
    signer
  );
  console.log("  ✅ CombatResolver:", combatResolver.proxy);

  console.log("6/6 Deploying Marketplace proxy...");
  const marketplace = await deployUUPSProxy(
    "Marketplace",
    [admin, existing.SOULToken, existing.AFWToken, itemRegistry.proxy, existing.EconomyEngine],
    signer
  );
  console.log("  ✅ Marketplace:", marketplace.proxy);

  const COMBAT_ROLE = ethers.keccak256(ethers.toUtf8Bytes("COMBAT_ROLE"));
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  const BURNER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("BURNER_ROLE"));
  const MARKET_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MARKET_ROLE"));

  const agentRegistry = await ethers.getContractAt("AgentRegistry", existing.AgentRegistry, signer);
  const soulToken = await ethers.getContractAt("SOULToken", existing.SOULToken, signer);
  const economyEngine = await ethers.getContractAt("EconomyEngine", existing.EconomyEngine, signer);

  console.log("\n🔑 Configuring roles and dependencies...");
  await sendAndWait(agentRegistry.grantRole(COMBAT_ROLE, combatResolver.proxy, feeOverrides));
  await sendAndWait(soulToken.grantRole(MINTER_ROLE, combatResolver.proxy, feeOverrides));
  await sendAndWait(soulToken.grantRole(BURNER_ROLE, combatResolver.proxy, feeOverrides));
  await sendAndWait(itemRegistry.contract.grantRole(MINTER_ROLE, npcRegistry.proxy, feeOverrides));
  await sendAndWait(eventTreasury.contract.grantRole(COMBAT_ROLE, monsterRegistry.proxy, feeOverrides));
  await sendAndWait(monsterRegistry.contract.grantRole(COMBAT_ROLE, combatResolver.proxy, feeOverrides));
  await sendAndWait(monsterRegistry.contract.setEventTreasury(eventTreasury.proxy, feeOverrides));
  await sendAndWait(economyEngine.grantRole(MARKET_ROLE, marketplace.proxy, feeOverrides));
  console.log("  ✅ Roles configured");

  const updated: DeploymentsFile = {
    ...existing,
    network: (await ethers.provider.getNetwork()).name,
    ItemRegistry: itemRegistry.proxy,
    MonsterRegistry: monsterRegistry.proxy,
    NPCRegistry: npcRegistry.proxy,
    EventTreasury: eventTreasury.proxy,
    CombatResolver: combatResolver.proxy,
    Marketplace: marketplace.proxy,
    implementations: {
      ...existing.implementations,
      ItemRegistry: itemRegistry.implementation,
      MonsterRegistry: monsterRegistry.implementation,
      NPCRegistry: npcRegistry.implementation,
      EventTreasury: eventTreasury.implementation,
      CombatResolver: combatResolver.implementation,
      Marketplace: marketplace.implementation,
    },
  };

  fs.writeFileSync(deploymentsPath, JSON.stringify(updated, null, 2));

  console.log("\n✅ Phase 3 addresses saved to deployments.json");
  console.log("ItemRegistry:", updated.ItemRegistry);
  console.log("MonsterRegistry:", updated.MonsterRegistry);
  console.log("NPCRegistry:", updated.NPCRegistry);
  console.log("EventTreasury:", updated.EventTreasury);
  console.log("CombatResolver:", updated.CombatResolver);
  console.log("Marketplace:", updated.Marketplace);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
