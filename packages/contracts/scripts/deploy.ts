import { ethers } from "hardhat";

type ProxyDeployment<T> = {
  implementation: string;
  proxy: string;
  contract: T;
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
  const [deployer] = await ethers.getSigners();
  const signer = new ethers.NonceManager(deployer);
  const admin = process.env.MULTISIG_ADMIN_ADDRESS || deployer.address;
  const engineOracleAddress = process.env.AGENT_ENGINE_ORACLE_ADDRESS || deployer.address;
  const eventTreasuryAddress = process.env.EVENT_TREASURY_ADDRESS || deployer.address;
  const feeOverrides = await getFeeOverrides();

  console.log("🏰 AFW Deploying with:", deployer.address);
  console.log("Admin:", admin);
  console.log("Event Treasury:", eventTreasuryAddress);
  console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH\n");
  console.log("Fee overrides:", feeOverrides);

  console.log("1/9 Deploying AFWToken proxy...");
  const afwToken = await deployUUPSProxy("AFWToken", [
    admin,
    deployer.address,
    deployer.address,
    deployer.address,
    deployer.address,
    deployer.address,
    deployer.address,
  ], signer);
  console.log("  ✅ AFWToken proxy:", afwToken.proxy);

  console.log("2/9 Deploying SOULToken proxy...");
  const soulToken = await deployUUPSProxy("SOULToken", [admin], signer);
  console.log("  ✅ SOULToken proxy:", soulToken.proxy);

  console.log("3/9 Deploying WorldMap proxy...");
  const worldMap = await deployUUPSProxy("WorldMap", [admin], signer);
  console.log("  ✅ WorldMap proxy:", worldMap.proxy);

  console.log("4/9 Deploying AgentRegistry proxy...");
  const agentRegistry = await deployUUPSProxy("AgentRegistry", [admin], signer);
  console.log("  ✅ AgentRegistry proxy:", agentRegistry.proxy);

  console.log("5/9 Deploying NodeRegistry proxy...");
  const nodeRegistry = await deployUUPSProxy("NodeRegistry", [admin, afwToken.proxy], signer);
  console.log("  ✅ NodeRegistry proxy:", nodeRegistry.proxy);

  console.log("6/9 Deploying OracleGateway proxy...");
  const oracleGateway = await deployUUPSProxy("OracleGateway", [admin, agentRegistry.proxy], signer);
  console.log("  ✅ OracleGateway proxy:", oracleGateway.proxy);

  console.log("7/9 Deploying EconomyEngine proxy...");
  const economyEngine = await deployUUPSProxy("EconomyEngine", [admin, soulToken.proxy, eventTreasuryAddress], signer);
  console.log("  ✅ EconomyEngine proxy:", economyEngine.proxy);

  console.log("8/9 Deploying QuestEngine proxy...");
  const questEngine = await deployUUPSProxy("QuestEngine", [admin, agentRegistry.proxy, economyEngine.proxy], signer);
  console.log("  ✅ QuestEngine proxy:", questEngine.proxy);

  console.log("9/9 Deploying GovernanceDAO proxy...");
  const governanceDAO = await deployUUPSProxy("GovernanceDAO", [admin, afwToken.proxy, nodeRegistry.proxy], signer);
  console.log("  ✅ GovernanceDAO proxy:", governanceDAO.proxy);

  console.log("\n🔑 Setting up roles...");
  const ORACLE_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ORACLE_ROLE"));
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  const BURNER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("BURNER_ROLE"));
  const QUEST_ROLE = ethers.keccak256(ethers.toUtf8Bytes("QUEST_ROLE"));
  const COMBAT_ROLE = ethers.keccak256(ethers.toUtf8Bytes("COMBAT_ROLE"));
  const NODE_REGISTRY_ROLE = ethers.keccak256(ethers.toUtf8Bytes("NODE_REGISTRY_ROLE"));

  await sendAndWait(agentRegistry.contract.grantRole(ORACLE_ROLE, oracleGateway.proxy, feeOverrides));
  await sendAndWait(agentRegistry.contract.grantRole(ORACLE_ROLE, engineOracleAddress, feeOverrides));
  await sendAndWait(soulToken.contract.grantRole(MINTER_ROLE, economyEngine.proxy, feeOverrides));
  await sendAndWait(soulToken.contract.grantRole(BURNER_ROLE, economyEngine.proxy, feeOverrides));
  await sendAndWait(economyEngine.contract.grantRole(QUEST_ROLE, questEngine.proxy, feeOverrides));
  await sendAndWait(economyEngine.contract.grantRole(COMBAT_ROLE, engineOracleAddress, feeOverrides));
  await sendAndWait(worldMap.contract.grantRole(NODE_REGISTRY_ROLE, nodeRegistry.proxy, feeOverrides));
  await sendAndWait(afwToken.contract.setGovernanceDAO(governanceDAO.proxy, feeOverrides));
  await sendAndWait(soulToken.contract.setGovernanceDAO(governanceDAO.proxy, feeOverrides));
  await sendAndWait(nodeRegistry.contract.setWorldMap(worldMap.proxy, feeOverrides));

  console.log("  ✅ Roles configured");

  console.log("\n🌱 Seeding registry data...");
  const fixedClass = (hp: number, mp: number, atk: number, def: number, spd: number) => ({
    hp,
    maxHp: hp,
    mp,
    maxMp: mp,
    attack: atk,
    defense: def,
    speed: spd,
  });

  await sendAndWait(agentRegistry.contract.registerClass("Warrior", fixedClass(100, 50, 20, 15, 10), fixedClass(100, 50, 20, 15, 10), feeOverrides));
  await sendAndWait(agentRegistry.contract.registerClass("Mage", fixedClass(70, 120, 25, 8, 12), fixedClass(70, 120, 25, 8, 12), feeOverrides));
  await sendAndWait(agentRegistry.contract.registerClass("Ranger", fixedClass(80, 60, 18, 12, 16), fixedClass(80, 60, 18, 12, 16), feeOverrides));
  await sendAndWait(agentRegistry.contract.registerClass("Healer", fixedClass(75, 100, 10, 10, 11), fixedClass(75, 100, 10, 10, 11), feeOverrides));
  await sendAndWait(agentRegistry.contract.registerClass("Tank", fixedClass(150, 30, 12, 25, 7), fixedClass(150, 30, 12, 25, 7), feeOverrides));

  await sendAndWait(agentRegistry.contract.registerStatus("ALIVE", false, feeOverrides));
  await sendAndWait(agentRegistry.contract.registerStatus("DEAD", true, feeOverrides));
  await sendAndWait(agentRegistry.contract.registerStatus("RESTING", false, feeOverrides));
  await sendAndWait(agentRegistry.contract.registerStatus("IN_COMBAT", false, feeOverrides));
  await sendAndWait(agentRegistry.contract.registerStatus("TRAVELING", false, feeOverrides));

  await sendAndWait(worldMap.contract.registerDangerLevel("SAFE", 1, 10, feeOverrides));
  await sendAndWait(worldMap.contract.registerDangerLevel("MEDIUM", 11, 25, feeOverrides));
  await sendAndWait(worldMap.contract.registerDangerLevel("DANGER", 26, 50, feeOverrides));
  await sendAndWait(worldMap.contract.registerDangerLevel("EXTREME", 51, 99, feeOverrides));

  await sendAndWait(worldMap.contract.registerZone("Lumenveil", "빛의 베일", 1, 1, 100, [], feeOverrides));
  await sendAndWait(worldMap.contract.registerZone("Graymarch", "회색 행진", 2, 10, 200, [1], feeOverrides));
  await sendAndWait(worldMap.contract.registerZone("Embervault", "잿불 지하", 3, 50, 150, [2], feeOverrides));
  await sendAndWait(worldMap.contract.registerZone("Voidreach", "공허의 끝", 4, 200, 50, [3], feeOverrides));

  console.log("  ✅ Initial classes, statuses, danger levels, and zones registered");

  const addresses = {
    network: (await ethers.provider.getNetwork()).name,
    AFWToken: afwToken.proxy,
    SOULToken: soulToken.proxy,
    WorldMap: worldMap.proxy,
    AgentRegistry: agentRegistry.proxy,
    NodeRegistry: nodeRegistry.proxy,
    OracleGateway: oracleGateway.proxy,
    EconomyEngine: economyEngine.proxy,
    QuestEngine: questEngine.proxy,
    GovernanceDAO: governanceDAO.proxy,
    implementations: {
      AFWToken: afwToken.implementation,
      SOULToken: soulToken.implementation,
      WorldMap: worldMap.implementation,
      AgentRegistry: agentRegistry.implementation,
      NodeRegistry: nodeRegistry.implementation,
      OracleGateway: oracleGateway.implementation,
      EconomyEngine: economyEngine.implementation,
      QuestEngine: questEngine.implementation,
      GovernanceDAO: governanceDAO.implementation,
    },
  };

  console.log("\n🏰 ====== AFW DEPLOYED ======");
  Object.entries(addresses).forEach(([name, addr]) => {
    if (name === "implementations") return;
    console.log(`  ${name.padEnd(15)}: ${addr}`);
  });

  const fs = await import("fs");
  fs.writeFileSync("deployments.json", JSON.stringify(addresses, null, 2));
  console.log("\n✅ Proxy addresses saved to deployments.json");
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
