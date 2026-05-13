import { ethers } from "hardhat";

type DeploymentsFile = {
  network: string;
  NodeRegistry: string;
  implementations: Record<string, string>;
};

type ActiveNode = {
  address: string;
  endpoint: string;
  active: boolean;
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

async function readActiveNodes(nodeRegistry: any): Promise<ActiveNode[]> {
  const count = await nodeRegistry.getActiveNodeCount();
  const nodes: ActiveNode[] = [];

  for (let index = 0; index < Number(count); index++) {
    try {
      const address = await nodeRegistry.activeNodes(index);
      const info = await nodeRegistry.nodes(address);
      nodes.push({
        address,
        endpoint: info.endpoint,
        active: info.isActive,
      });
    } catch (error) {
      console.warn(
        `Skipping unreadable activeNodes(${index}); RPC may be lagging after pruning.`,
        error
      );
    }
  }

  return nodes;
}

function staleEndpointPatterns() {
  const fromEnv = process.env.STALE_NODE_ENDPOINT_PATTERNS;
  if (fromEnv) {
    return fromEnv
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean);
  }

  return ["127.0.0.1", "localhost", "loca.lt"];
}

function shouldDeactivate(node: ActiveNode) {
  if (!node.active) return false;

  const durableEndpoint = process.env.TIER4_NODE_PUBLIC_URL || "";
  if (durableEndpoint && node.endpoint === durableEndpoint) return false;

  return staleEndpointPatterns().some((pattern) =>
    node.endpoint.includes(pattern)
  );
}

async function main() {
  const fs = await import("fs");
  const deploymentsPath = "deployments.json";
  const existing = JSON.parse(
    fs.readFileSync(deploymentsPath, "utf8")
  ) as DeploymentsFile;

  const [deployer] = await ethers.getSigners();
  const signer = new ethers.NonceManager(deployer);
  const feeOverrides = await getFeeOverrides();

  console.log("Phase 2 NodeRegistry upgrade and stale node cleanup");
  console.log("Deployer:", deployer.address);
  console.log("NodeRegistry proxy:", existing.NodeRegistry);
  console.log(
    "Previous implementation:",
    existing.implementations.NodeRegistry
  );
  console.log(
    "Balance:",
    ethers.formatEther(await ethers.provider.getBalance(deployer.address)),
    "ETH"
  );
  console.log("Stale endpoint patterns:", staleEndpointPatterns());

  const factory = await ethers.getContractFactory("NodeRegistry", signer);
  const implementation = await factory.deploy(feeOverrides);
  await implementation.waitForDeployment();
  const implementationAddress = await implementation.getAddress();
  console.log("New implementation:", implementationAddress);

  const nodeRegistry = await ethers.getContractAt(
    "NodeRegistry",
    existing.NodeRegistry,
    signer
  );
  const defaultAdminRole = await nodeRegistry.DEFAULT_ADMIN_ROLE();
  const slasherRole = await nodeRegistry.SLASHER_ROLE();

  if (!(await nodeRegistry.hasRole(defaultAdminRole, deployer.address))) {
    throw new Error(
      `Deployer ${deployer.address} does not have DEFAULT_ADMIN_ROLE on NodeRegistry.`
    );
  }

  const upgradeReceipt = await sendAndWait(
    nodeRegistry.upgradeToAndCall(implementationAddress, "0x", feeOverrides)
  );
  console.log("Upgrade tx:", upgradeReceipt?.hash);

  const grantedTemporarySlasherRole = !(await nodeRegistry.hasRole(
    slasherRole,
    deployer.address
  ));

  if (grantedTemporarySlasherRole) {
    const grantReceipt = await sendAndWait(
      nodeRegistry.grantRole(slasherRole, deployer.address, feeOverrides)
    );
    console.log("Granted SLASHER_ROLE to deployer:", grantReceipt?.hash);
  } else {
    console.log("SLASHER_ROLE already granted to deployer.");
  }

  const before = await readActiveNodes(nodeRegistry);
  console.log("Active nodes before cleanup:", before);

  const staleNodes = before.filter(shouldDeactivate);
  for (const node of staleNodes) {
    const receipt = await sendAndWait(
      nodeRegistry["deactivateNode(address)"](node.address, feeOverrides)
    );
    console.log(
      `Deactivated stale node ${node.address} (${node.endpoint}):`,
      receipt?.hash
    );
  }

  const after = await readActiveNodes(nodeRegistry);
  console.log("Active nodes after cleanup:", after);

  if (
    grantedTemporarySlasherRole &&
    process.env.KEEP_DEPLOYER_SLASHER_ROLE !== "true"
  ) {
    const revokeReceipt = await sendAndWait(
      nodeRegistry.revokeRole(slasherRole, deployer.address, feeOverrides)
    );
    console.log(
      "Revoked temporary SLASHER_ROLE from deployer:",
      revokeReceipt?.hash
    );
  }

  const updated: DeploymentsFile = {
    ...existing,
    implementations: {
      ...existing.implementations,
      NodeRegistry: implementationAddress,
    },
  };

  fs.writeFileSync(deploymentsPath, JSON.stringify(updated, null, 2));
  console.log("deployments.json updated with new NodeRegistry implementation.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
