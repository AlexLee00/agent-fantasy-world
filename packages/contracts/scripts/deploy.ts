import { ethers } from "hardhat";

/**
 * AFW 전체 컨트랙트 배포 스크립트
 * 순서: Token → Registry → Engine → Governance
 *
 * 실행:
 *   npx hardhat run scripts/deploy.ts --network localhost
 *   npx hardhat run scripts/deploy.ts --network amoy
 */
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("🏰 AFW Deploying with:", deployer.address);
  console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH\n");

  // ── 1. 토큰 배포 ──────────────────────────────────────────────
  console.log("1/8 Deploying AFWToken...");
  const AFWToken = await ethers.deployContract("AFWToken", [
    deployer.address, // nodeMiningPool  (40%)
    deployer.address, // communityPool   (25%)
    deployer.address, // teamVesting     (15%)
    deployer.address, // ecosystemPool   (10%)
    deployer.address, // liquidityPool   ( 5%)
    deployer.address, // advisorVesting  ( 5%)
  ]);
  await AFWToken.waitForDeployment();
  console.log("  ✅ AFWToken:", await AFWToken.getAddress());

  console.log("2/8 Deploying SOULToken...");
  const dailyMintLimit = ethers.parseEther("1000000"); // 100만 SOUL/일
  const SOULToken = await ethers.deployContract("SOULToken", [dailyMintLimit]);
  await SOULToken.waitForDeployment();
  console.log("  ✅ SOULToken:", await SOULToken.getAddress());

  // ── 2. 월드 맵 ────────────────────────────────────────────────
  console.log("3/8 Deploying WorldMap...");
  const WorldMap = await ethers.deployContract("WorldMap");
  await WorldMap.waitForDeployment();
  console.log("  ✅ WorldMap:", await WorldMap.getAddress());

  // ── 3. 에이전트 레지스트리 ────────────────────────────────────
  console.log("4/8 Deploying AgentRegistry...");
  const AgentRegistry = await ethers.deployContract("AgentRegistry");
  await AgentRegistry.waitForDeployment();
  console.log("  ✅ AgentRegistry:", await AgentRegistry.getAddress());

  // ── 4. 노드 시스템 ────────────────────────────────────────────
  console.log("5/8 Deploying NodeRegistry...");
  const NodeRegistry = await ethers.deployContract("NodeRegistry", [
    await AFWToken.getAddress()
  ]);
  await NodeRegistry.waitForDeployment();
  console.log("  ✅ NodeRegistry:", await NodeRegistry.getAddress());

  console.log("6/8 Deploying OracleGateway...");
  const OracleGateway = await ethers.deployContract("OracleGateway", [
    await AgentRegistry.getAddress()
  ]);
  await OracleGateway.waitForDeployment();
  console.log("  ✅ OracleGateway:", await OracleGateway.getAddress());

  // ── 5. 경제 + 퀘스트 ─────────────────────────────────────────
  console.log("7/8 Deploying EconomyEngine + QuestEngine...");
  const EconomyEngine = await ethers.deployContract("EconomyEngine", [
    await SOULToken.getAddress()
  ]);
  await EconomyEngine.waitForDeployment();
  console.log("  ✅ EconomyEngine:", await EconomyEngine.getAddress());

  const QuestEngine = await ethers.deployContract("QuestEngine", [
    await AgentRegistry.getAddress(),
    await EconomyEngine.getAddress()
  ]);
  await QuestEngine.waitForDeployment();
  console.log("  ✅ QuestEngine:", await QuestEngine.getAddress());

  // ── 6. 거버넌스 ──────────────────────────────────────────────
  console.log("8/8 Deploying GovernanceDAO...");
  const GovernanceDAO = await ethers.deployContract("GovernanceDAO", [
    await AFWToken.getAddress(),
    await NodeRegistry.getAddress()
  ]);
  await GovernanceDAO.waitForDeployment();
  console.log("  ✅ GovernanceDAO:", await GovernanceDAO.getAddress());

  // ── 7. 권한 설정 ─────────────────────────────────────────────
  console.log("\n🔑 Setting up roles...");
  const ORACLE_ROLE  = ethers.keccak256(ethers.toUtf8Bytes("ORACLE_ROLE"));
  const MINTER_ROLE  = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  const BURNER_ROLE  = ethers.keccak256(ethers.toUtf8Bytes("BURNER_ROLE"));
  const QUEST_ROLE   = ethers.keccak256(ethers.toUtf8Bytes("QUEST_ROLE"));
  const MARKET_ROLE  = ethers.keccak256(ethers.toUtf8Bytes("MARKET_ROLE"));

  await AgentRegistry.grantRole(ORACLE_ROLE, await OracleGateway.getAddress());
  await SOULToken.grantRole(MINTER_ROLE, await EconomyEngine.getAddress());
  await SOULToken.grantRole(BURNER_ROLE, await EconomyEngine.getAddress());
  await EconomyEngine.grantRole(QUEST_ROLE, await QuestEngine.getAddress());
  console.log("  ✅ Roles configured");

  // ── 8. 배포 주소 요약 ────────────────────────────────────────
  const addresses = {
    AFWToken:       await AFWToken.getAddress(),
    SOULToken:      await SOULToken.getAddress(),
    WorldMap:       await WorldMap.getAddress(),
    AgentRegistry:  await AgentRegistry.getAddress(),
    NodeRegistry:   await NodeRegistry.getAddress(),
    OracleGateway:  await OracleGateway.getAddress(),
    EconomyEngine:  await EconomyEngine.getAddress(),
    QuestEngine:    await QuestEngine.getAddress(),
    GovernanceDAO:  await GovernanceDAO.getAddress(),
  };

  console.log("\n🏰 ====== AFW DEPLOYED ======");
  Object.entries(addresses).forEach(([name, addr]) => {
    console.log(`  ${name.padEnd(15)}: ${addr}`);
  });

  // JSON으로 저장
  const fs = await import("fs");
  fs.writeFileSync(
    "deployments.json",
    JSON.stringify({ network: (await ethers.provider.getNetwork()).name, ...addresses }, null, 2)
  );
  console.log("\n✅ Addresses saved to deployments.json");
}

main().catch((e) => { console.error(e); process.exitCode = 1; });
