import { ethers } from "hardhat";

async function main() {
  let totalGas = 0n;

  async function addReceiptGas(txPromise: Promise<any>) {
    const tx = await txPromise;
    const receipt = await tx.wait();
    totalGas += receipt!.gasUsed;
    return receipt;
  }

  async function deployUUPSProxy(contractName: string, initArgs: any[]) {
    const factory = await ethers.getContractFactory(contractName);
    const implementation = await factory.deploy();
    const implementationReceipt = await implementation.deploymentTransaction()!.wait();
    totalGas += implementationReceipt!.gasUsed;

    const proxyFactory = await ethers.getContractFactory("AFWUUPSProxy");
    const initData = factory.interface.encodeFunctionData("initialize", initArgs);
    const proxy = await proxyFactory.deploy(await implementation.getAddress(), initData);
    const proxyReceipt = await proxy.deploymentTransaction()!.wait();
    totalGas += proxyReceipt!.gasUsed;

    return {
      implementation: await implementation.getAddress(),
      proxy: await proxy.getAddress(),
      contract: await ethers.getContractAt(contractName, await proxy.getAddress()),
      implementationGas: implementationReceipt!.gasUsed,
      proxyGas: proxyReceipt!.gasUsed,
    };
  }

  const [deployer] = await ethers.getSigners();
  const admin = deployer.address;
  const eventTreasury = deployer.address;

  const afwToken = await deployUUPSProxy("AFWToken", [
    admin,
    deployer.address,
    deployer.address,
    deployer.address,
    deployer.address,
    deployer.address,
    deployer.address,
  ]);
  const soulToken = await deployUUPSProxy("SOULToken", [admin]);
  const worldMap = await deployUUPSProxy("WorldMap", [admin]);
  const agentRegistry = await deployUUPSProxy("AgentRegistry", [admin]);
  const nodeRegistry = await deployUUPSProxy("NodeRegistry", [admin, afwToken.proxy]);
  const oracleGateway = await deployUUPSProxy("OracleGateway", [admin, agentRegistry.proxy]);
  const economyEngine = await deployUUPSProxy("EconomyEngine", [admin, soulToken.proxy, eventTreasury]);
  const questEngine = await deployUUPSProxy("QuestEngine", [admin, agentRegistry.proxy, economyEngine.proxy]);
  const governanceDAO = await deployUUPSProxy("GovernanceDAO", [admin, afwToken.proxy, nodeRegistry.proxy]);

  const ORACLE_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ORACLE_ROLE"));
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  const BURNER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("BURNER_ROLE"));
  const QUEST_ROLE = ethers.keccak256(ethers.toUtf8Bytes("QUEST_ROLE"));
  const COMBAT_ROLE = ethers.keccak256(ethers.toUtf8Bytes("COMBAT_ROLE"));
  const NODE_REGISTRY_ROLE = ethers.keccak256(ethers.toUtf8Bytes("NODE_REGISTRY_ROLE"));

  await addReceiptGas(agentRegistry.contract.grantRole(ORACLE_ROLE, oracleGateway.proxy));
  await addReceiptGas(agentRegistry.contract.grantRole(ORACLE_ROLE, deployer.address));
  await addReceiptGas(soulToken.contract.grantRole(MINTER_ROLE, economyEngine.proxy));
  await addReceiptGas(soulToken.contract.grantRole(BURNER_ROLE, economyEngine.proxy));
  await addReceiptGas(economyEngine.contract.grantRole(QUEST_ROLE, questEngine.proxy));
  await addReceiptGas(economyEngine.contract.grantRole(COMBAT_ROLE, deployer.address));
  await addReceiptGas(worldMap.contract.grantRole(NODE_REGISTRY_ROLE, nodeRegistry.proxy));
  await addReceiptGas(afwToken.contract.setGovernanceDAO(governanceDAO.proxy));
  await addReceiptGas(soulToken.contract.setGovernanceDAO(governanceDAO.proxy));
  await addReceiptGas(nodeRegistry.contract.setWorldMap(worldMap.proxy));

  const fixedClass = (hp: number, mp: number, attack: number, defense: number, speed: number) => ({
    hp,
    maxHp: hp,
    mp,
    maxMp: mp,
    attack,
    defense,
    speed,
  });

  await addReceiptGas(agentRegistry.contract.registerClass("Warrior", fixedClass(100, 50, 20, 15, 10), fixedClass(100, 50, 20, 15, 10)));
  await addReceiptGas(agentRegistry.contract.registerClass("Mage", fixedClass(70, 120, 25, 8, 12), fixedClass(70, 120, 25, 8, 12)));
  await addReceiptGas(agentRegistry.contract.registerClass("Ranger", fixedClass(80, 60, 18, 12, 16), fixedClass(80, 60, 18, 12, 16)));
  await addReceiptGas(agentRegistry.contract.registerClass("Healer", fixedClass(75, 100, 10, 10, 11), fixedClass(75, 100, 10, 10, 11)));
  await addReceiptGas(agentRegistry.contract.registerClass("Tank", fixedClass(150, 30, 12, 25, 7), fixedClass(150, 30, 12, 25, 7)));

  await addReceiptGas(agentRegistry.contract.registerStatus("ALIVE", false));
  await addReceiptGas(agentRegistry.contract.registerStatus("DEAD", true));
  await addReceiptGas(agentRegistry.contract.registerStatus("RESTING", false));
  await addReceiptGas(agentRegistry.contract.registerStatus("IN_COMBAT", false));
  await addReceiptGas(agentRegistry.contract.registerStatus("TRAVELING", false));

  await addReceiptGas(worldMap.contract.registerDangerLevel("SAFE", 1, 10));
  await addReceiptGas(worldMap.contract.registerDangerLevel("MEDIUM", 11, 25));
  await addReceiptGas(worldMap.contract.registerDangerLevel("DANGER", 26, 50));
  await addReceiptGas(worldMap.contract.registerDangerLevel("EXTREME", 51, 99));

  await addReceiptGas(worldMap.contract.registerZone("Lumenveil", "빛의 베일", 1, 1, 100, []));
  await addReceiptGas(worldMap.contract.registerZone("Graymarch", "회색 행진", 2, 10, 200, [1]));
  await addReceiptGas(worldMap.contract.registerZone("Embervault", "잿불 지하", 3, 50, 150, [2]));
  await addReceiptGas(worldMap.contract.registerZone("Voidreach", "공허의 끝", 4, 200, 50, [3]));

  console.log(JSON.stringify({
    totalGas: totalGas.toString(),
    firstImplementationGas: afwToken.implementationGas.toString(),
    firstProxyGas: afwToken.proxyGas.toString(),
  }, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
