import { expect } from "chai";
import { ethers } from "hardhat";
import { deployProxy } from "./helpers";

const spec = {
  cpuCores: 8,
  ramGB: 32,
  gpuVramGB: 16,
  bandwidthMbps: 1000,
};

describe("NodeRegistry", function () {
  it("registers nodes and lets operators update endpoints", async function () {
    const [, operator] = await ethers.getSigners();
    const { contract: registry } = await deployProxy("NodeRegistry", [
      operator.address,
      ethers.ZeroAddress,
    ]);

    await registry
      .connect(operator)
      .registerNode(0, spec, "https://node.example.com/infer");
    await registry
      .connect(operator)
      .updateEndpoint("https://node-2.example.com/infer");

    const info = await registry.nodes(operator.address);
    expect(info.isActive).to.equal(true);
    expect(info.endpoint).to.equal("https://node-2.example.com/infer");
    expect(await registry.getActiveNodeCount()).to.equal(1);
  });

  it("allows self-deactivation and removes the node from activeNodes", async function () {
    const [, first, second] = await ethers.getSigners();
    const { contract: registry } = await deployProxy("NodeRegistry", [
      first.address,
      ethers.ZeroAddress,
    ]);

    await registry
      .connect(first)
      .registerNode(0, spec, "https://first.example.com/infer");
    await registry
      .connect(second)
      .registerNode(0, spec, "https://second.example.com/infer");
    await registry.connect(first)["deactivateNode()"]();

    const firstInfo = await registry.nodes(first.address);
    expect(firstInfo.isActive).to.equal(false);
    expect(await registry.getActiveNodeCount()).to.equal(1);
    expect(await registry.activeNodes(0)).to.equal(second.address);
    expect(await registry.calculateReward(first.address)).to.equal(0);
  });

  it("allows slasher role to deactivate stale nodes without slashing stake", async function () {
    const [admin, operator] = await ethers.getSigners();
    const { contract: registry } = await deployProxy("NodeRegistry", [
      admin.address,
      ethers.ZeroAddress,
    ]);
    const slasherRole = await registry.SLASHER_ROLE();

    await registry.grantRole(slasherRole, admin.address);
    await registry
      .connect(operator)
      .registerNode(0, spec, "https://stale.example.com/infer");
    await registry["deactivateNode(address)"](operator.address);

    const info = await registry.nodes(operator.address);
    expect(info.isActive).to.equal(false);
    expect(info.stakedAFW).to.equal(ethers.parseEther("1000"));
    expect(await registry.getActiveNodeCount()).to.equal(0);
  });

  it("prunes activeNodes when slashing deactivates a node", async function () {
    const [admin, first, second] = await ethers.getSigners();
    const { contract: registry } = await deployProxy("NodeRegistry", [
      admin.address,
      ethers.ZeroAddress,
    ]);
    const slasherRole = await registry.SLASHER_ROLE();

    await registry.grantRole(slasherRole, admin.address);
    await registry
      .connect(first)
      .registerNode(0, spec, "https://first.example.com/infer");
    await registry
      .connect(second)
      .registerNode(0, spec, "https://second.example.com/infer");
    await registry.slash(first.address, 2);

    const firstInfo = await registry.nodes(first.address);
    expect(firstInfo.isActive).to.equal(false);
    expect(await registry.getActiveNodeCount()).to.equal(1);
    expect(await registry.activeNodes(0)).to.equal(second.address);
  });
});
