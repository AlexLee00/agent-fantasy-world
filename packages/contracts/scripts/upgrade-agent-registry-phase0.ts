import { ethers } from "hardhat";

type DeploymentsFile = {
  network: string;
  AgentRegistry: string;
  CombatResolver: string;
  implementations: Record<string, string>;
};

async function sendAndWait(txPromise: Promise<any>) {
  const tx = await txPromise;
  const receipt = await tx.wait();
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
    return {
      gasPrice: feeData.gasPrice * 3n,
    };
  }

  return {};
}

async function assertApplyCombatResultReachable(agentRegistryAddress: string, combatResolverAddress: string) {
  const agentRegistry = await ethers.getContractAt("AgentRegistry", agentRegistryAddress);
  const totalAgents = await agentRegistry.totalAgents();

  if (totalAgents === 0n) {
    console.log("No agents exist yet; skipping applyCombatResult live probe.");
    return;
  }

  const sampleAgentId = 1n;
  const sample = await agentRegistry.getAgent(sampleAgentId);
  const data = agentRegistry.interface.encodeFunctionData("applyCombatResult", [
    sampleAgentId,
    sample.stats,
    sample.experience,
    sample.zoneId,
    sample.statusId,
  ]);

  await ethers.provider.call({
    from: combatResolverAddress,
    to: agentRegistryAddress,
    data,
  });

  console.log("Live probe OK: AgentRegistry.applyCombatResult is reachable from CombatResolver.");
}

async function main() {
  const fs = await import("fs");
  const deploymentsPath = "deployments.json";
  const existing = JSON.parse(fs.readFileSync(deploymentsPath, "utf8")) as DeploymentsFile;

  const [deployer] = await ethers.getSigners();
  const signer = new ethers.NonceManager(deployer);
  const feeOverrides = await getFeeOverrides();

  console.log("Phase 0 AgentRegistry upgrade");
  console.log("Deployer:", deployer.address);
  console.log("AgentRegistry proxy:", existing.AgentRegistry);
  console.log("Previous implementation:", existing.implementations.AgentRegistry);
  console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");
  console.log("Fee overrides:", feeOverrides);

  const factory = await ethers.getContractFactory("AgentRegistry", signer);
  const implementation = await factory.deploy(feeOverrides);
  await implementation.waitForDeployment();
  const implementationAddress = await implementation.getAddress();
  console.log("New implementation:", implementationAddress);

  const agentRegistry = await ethers.getContractAt("AgentRegistry", existing.AgentRegistry, signer);
  const upgradeReceipt = await sendAndWait(
    agentRegistry.upgradeToAndCall(implementationAddress, "0x", feeOverrides)
  );
  console.log("Upgrade tx:", upgradeReceipt?.hash);

  const COMBAT_ROLE = ethers.keccak256(ethers.toUtf8Bytes("COMBAT_ROLE"));
  const hasCombatRole = await agentRegistry.hasRole(COMBAT_ROLE, existing.CombatResolver);

  if (!hasCombatRole) {
    const grantReceipt = await sendAndWait(
      agentRegistry.grantRole(COMBAT_ROLE, existing.CombatResolver, feeOverrides)
    );
    console.log("Granted COMBAT_ROLE to CombatResolver:", grantReceipt?.hash);
  } else {
    console.log("COMBAT_ROLE already granted to CombatResolver.");
  }

  await assertApplyCombatResultReachable(existing.AgentRegistry, existing.CombatResolver);

  const updated: DeploymentsFile = {
    ...existing,
    implementations: {
      ...existing.implementations,
      AgentRegistry: implementationAddress,
    },
  };

  fs.writeFileSync(deploymentsPath, JSON.stringify(updated, null, 2));
  console.log("deployments.json updated with new AgentRegistry implementation.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
