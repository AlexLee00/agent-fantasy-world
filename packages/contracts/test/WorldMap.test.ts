import { expect } from "chai";
import { ethers } from "hardhat";
import { deployProxy, seedWorldMap } from "./helpers";

describe("WorldMap", function () {
  const NODE_REGISTRY_ROLE = ethers.keccak256(ethers.toUtf8Bytes("NODE_REGISTRY_ROLE"));

  async function setup() {
    const [admin, nodeRegistry, stranger] = await ethers.getSigners();
    const { contract: worldMap } = await deployProxy("WorldMap", [admin.address]);
    await seedWorldMap(worldMap);
    await worldMap.grantRole(NODE_REGISTRY_ROLE, nodeRegistry.address);
    return { worldMap, admin, nodeRegistry, stranger };
  }

  it("registers initial danger levels and zones", async function () {
    const { worldMap } = await setup();
    expect(await worldMap.totalDangerLevels()).to.equal(4);
    expect(await worldMap.totalZones()).to.equal(4);
    expect(await worldMap.isZoneUnlocked(1)).to.equal(true);

    const z1 = await worldMap.getZone(1);
    expect(z1.name).to.equal("Lumenveil");
    expect(z1.dangerId).to.equal(1);
  });

  it("allows open danger level registration", async function () {
    const { worldMap, stranger } = await setup();
    await expect(worldMap.connect(stranger).registerDangerLevel("MYTHIC", 60, 99))
      .to.emit(worldMap, "DangerLevelRegistered")
      .withArgs(5, "MYTHIC", 60, 99);
  });

  it("reverts on invalid danger level registration", async function () {
    const { worldMap, stranger } = await setup();
    await expect(worldMap.connect(stranger).registerDangerLevel("BROKEN", 0, 120))
      .to.be.revertedWith("WorldMap: min level too low");
  });

  it("unlocks zones when node threshold is reached", async function () {
    const { worldMap, nodeRegistry } = await setup();
    await expect(worldMap.connect(nodeRegistry).checkAndUnlock(200))
      .to.emit(worldMap, "ZoneUnlocked")
      .withArgs(2, "Graymarch", 200);

    expect(await worldMap.isZoneUnlocked(2)).to.equal(true);
    expect(await worldMap.isZoneUnlocked(3)).to.equal(true);
    expect(await worldMap.isZoneUnlocked(4)).to.equal(true);
    expect(await worldMap.unlockedZones()).to.equal(4);
  });
});
