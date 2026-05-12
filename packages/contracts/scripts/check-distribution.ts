import { ethers } from "hardhat";

type DeploymentsFile = Record<string, any>;

const REQUIRED = [
  "TeamVestingWallet",
  "AdvisorVestingWallet",
  "NodeRewardPool",
  "BountyPool",
  "EcosystemTreasury",
  "AFWDistributor",
] as const;

async function main() {
  const fs = await import("fs");
  const deployments = JSON.parse(fs.readFileSync("deployments.json", "utf8")) as DeploymentsFile;
  const [deployer] = await ethers.getSigners();
  const allowMissing = process.env.ALLOW_MISSING_DISTRIBUTION === "true";
  const distributionExecutor =
    process.env.DISTRIBUTION_EXECUTOR_ADDRESS ||
    process.env.MULTISIG_ADMIN_ADDRESS ||
    deployer.address;
  const distributorRole = ethers.keccak256(ethers.toUtf8Bytes("DISTRIBUTOR_ROLE"));

  const report: Record<string, any> = {
    network: deployments.network,
    checkedAt: new Date().toISOString(),
    deployer: deployer.address,
    distributionExecutor,
    missing: [],
    contracts: {},
    roles: {},
  };

  for (const key of REQUIRED) {
    const address = deployments[key];
    const code = address ? await ethers.provider.getCode(address) : "0x";
    report.contracts[key] = {
      address: address || null,
      deployed: code !== "0x",
      implementation: deployments.implementations?.[key] || null,
    };

    if (!address || code === "0x") {
      report.missing.push(key);
    }
  }

  if (deployments.NodeRewardPool) {
    const nodePool = await ethers.getContractAt("NodeRewardPool", deployments.NodeRewardPool);
    report.roles.NodeRewardPool = {
      executorHasDistributorRole: await nodePool.hasRole(distributorRole, distributionExecutor),
      distributorHasDistributorRole: deployments.AFWDistributor
        ? await nodePool.hasRole(distributorRole, deployments.AFWDistributor)
        : false,
    };
  }

  if (deployments.BountyPool) {
    const bountyPool = await ethers.getContractAt("BountyPool", deployments.BountyPool);
    report.roles.BountyPool = {
      executorHasDistributorRole: await bountyPool.hasRole(distributorRole, distributionExecutor),
      distributorHasDistributorRole: deployments.AFWDistributor
        ? await bountyPool.hasRole(distributorRole, deployments.AFWDistributor)
        : false,
    };
  }

  report.ready =
    report.missing.length === 0 &&
    report.roles.NodeRewardPool?.executorHasDistributorRole === true &&
    report.roles.BountyPool?.executorHasDistributorRole === true;

  console.log(JSON.stringify(report, null, 2));

  if (!report.ready && !allowMissing) {
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
