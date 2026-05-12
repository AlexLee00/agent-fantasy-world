import { ethers } from "hardhat";

type DeploymentsFile = Record<string, any>;

const ONE_BILLION_AFW = ethers.parseEther("1000000000");

async function sendAndWait(txPromise: Promise<any>, label: string) {
  const tx = await txPromise;
  console.log(`${label}: ${tx.hash}`);
  const receipt = await tx.wait();
  if (receipt?.status !== 1) {
    throw new Error(`${label} failed: ${tx.hash}`);
  }
  console.log(`${label} confirmed in block ${receipt?.blockNumber}`);
  return receipt;
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

async function main() {
  const fs = await import("fs");
  const deployments = JSON.parse(
    fs.readFileSync("deployments.json", "utf8")
  ) as DeploymentsFile;
  const [deployer] = await ethers.getSigners();
  const feeOverrides = await getFeeOverrides();

  if (!deployments.AFWToken || !deployments.AFWDistributor) {
    throw new Error("Missing AFWToken or AFWDistributor in deployments.json");
  }

  const afw = await ethers.getContractAt(
    "AFWToken",
    deployments.AFWToken,
    deployer
  );
  const distributor = await ethers.getContractAt(
    "AFWDistributor",
    deployments.AFWDistributor,
    deployer
  );
  const executed = await distributor.distributionExecuted();

  console.log("Distribution executor:", deployer.address);
  console.log("AFWDistributor:", deployments.AFWDistributor);
  console.log("distributionExecuted:", executed);

  if (executed) {
    console.log("Distribution was already executed. Nothing to do.");
    return;
  }

  const deployerBalance = await afw.balanceOf(deployer.address);
  const distributorBalance = await afw.balanceOf(deployments.AFWDistributor);
  const requiredTopUp = ONE_BILLION_AFW - distributorBalance;

  console.log("Deployer AFW:", ethers.formatEther(deployerBalance));
  console.log("Distributor AFW:", ethers.formatEther(distributorBalance));

  if (requiredTopUp > 0n) {
    if (deployerBalance < requiredTopUp) {
      throw new Error(
        `Insufficient deployer AFW. Need ${ethers.formatEther(
          requiredTopUp
        )}, have ${ethers.formatEther(deployerBalance)}`
      );
    }

    await sendAndWait(
      afw.transfer(deployments.AFWDistributor, requiredTopUp, feeOverrides),
      "fund AFWDistributor"
    );
  }

  await sendAndWait(
    distributor.executeDistribution(feeOverrides),
    "execute AFW distribution"
  );

  const targets = {
    teamWallet: await distributor.teamWallet(),
    marketplaceLiquidityWallet: await distributor.marketplaceLiquidityWallet(),
    teamVestingWallet: deployments.TeamVestingWallet,
    advisorVestingWallet: deployments.AdvisorVestingWallet,
    nodeRewardPool: deployments.NodeRewardPool,
    bountyPool: deployments.BountyPool,
    ecosystemTreasury: deployments.EcosystemTreasury,
  };

  const balances = Object.fromEntries(
    await Promise.all(
      Object.entries(targets).map(async ([label, address]) => [
        label,
        {
          address,
          afw: ethers.formatEther(await afw.balanceOf(address)),
        },
      ])
    )
  );

  console.log(
    JSON.stringify(
      {
        distributionExecuted: await distributor.distributionExecuted(),
        balances,
      },
      null,
      2
    )
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
