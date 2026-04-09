import { ethers } from "hardhat";

type DeploymentsFile = Record<string, any>;

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
    return { gasPrice: feeData.gasPrice * 3n };
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
  const raw = fs.readFileSync("deployments.json", "utf8");
  const existing = JSON.parse(raw) as DeploymentsFile;

  const [deployer] = await ethers.getSigners();
  const signer = new ethers.NonceManager(deployer);
  const admin = process.env.MULTISIG_ADMIN_ADDRESS || deployer.address;
  const teamWallet = process.env.TEAM_WALLET_ADDRESS || deployer.address;
  const advisorWallet = process.env.ADVISOR_WALLET_ADDRESS || deployer.address;
  const lpWallet = process.env.MARKETPLACE_LP_WALLET || deployer.address;
  const feeOverrides = await getFeeOverrides();

  console.log("Distribution deployer:", deployer.address);
  console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");

  const now = Math.floor(Date.now() / 1000);

  const teamVesting = await deployUUPSProxy("VestingWallet", [
    admin,
    existing.AFWToken,
    teamWallet,
    now,
    30 * 24 * 60 * 60,
    48,
    ethers.parseEther("135000000"),
  ], signer);

  const advisorVesting = await deployUUPSProxy("VestingWallet", [
    admin,
    existing.AFWToken,
    advisorWallet,
    now,
    90 * 24 * 60 * 60,
    8,
    ethers.parseEther("50000000"),
  ], signer);

  const nodeRewardPool = await deployUUPSProxy("NodeRewardPool", [admin, existing.AFWToken], signer);
  const bountyPool = await deployUUPSProxy("BountyPool", [admin, existing.AFWToken], signer);
  const ecosystemTreasury = await deployUUPSProxy("EcosystemTreasury", [admin, existing.AFWToken, 1], signer);
  const distributor = await deployUUPSProxy("AFWDistributor", [
    admin,
    existing.AFWToken,
    [teamWallet, advisorWallet, teamVesting.proxy, advisorVesting.proxy],
    [nodeRewardPool.proxy, bountyPool.proxy, ecosystemTreasury.proxy, lpWallet],
  ], signer);

  const DISTRIBUTOR_ROLE = ethers.keccak256(ethers.toUtf8Bytes("DISTRIBUTOR_ROLE"));

  await sendAndWait(nodeRewardPool.contract.grantRole(DISTRIBUTOR_ROLE, distributor.proxy, feeOverrides));
  await sendAndWait(bountyPool.contract.grantRole(DISTRIBUTOR_ROLE, distributor.proxy, feeOverrides));

  existing.TeamVestingWallet = teamVesting.proxy;
  existing.AdvisorVestingWallet = advisorVesting.proxy;
  existing.NodeRewardPool = nodeRewardPool.proxy;
  existing.BountyPool = bountyPool.proxy;
  existing.EcosystemTreasury = ecosystemTreasury.proxy;
  existing.AFWDistributor = distributor.proxy;
  existing.implementations = {
    ...existing.implementations,
    TeamVestingWallet: teamVesting.implementation,
    AdvisorVestingWallet: advisorVesting.implementation,
    NodeRewardPool: nodeRewardPool.implementation,
    BountyPool: bountyPool.implementation,
    EcosystemTreasury: ecosystemTreasury.implementation,
    AFWDistributor: distributor.implementation,
  };

  fs.writeFileSync("deployments.json", JSON.stringify(existing, null, 2));

  console.log("Distribution suite deployed.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
