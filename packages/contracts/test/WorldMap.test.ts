import { expect } from "chai";
import { ethers } from "hardhat";
import { WorldMap } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("WorldMap", function () {
  let worldMap: WorldMap;
  let admin: SignerWithAddress;
  let nodeRegistry: SignerWithAddress;
  let stranger: SignerWithAddress;

  const NODE_REGISTRY_ROLE = ethers.keccak256(ethers.toUtf8Bytes("NODE_REGISTRY_ROLE"));

  beforeEach(async function () {
    [admin, nodeRegistry, stranger] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory("WorldMap");
    worldMap = await Factory.deploy();
    await worldMap.grantRole(NODE_REGISTRY_ROLE, nodeRegistry.address);
  });

  describe("Initial zones", function () {
    it("should create 4 zones on deploy", async function () {
      expect(await worldMap.totalZones()).to.equal(4);
    });

    it("should unlock Lumenveil (zone 1) by default", async function () {
      expect(await worldMap.isZoneUnlocked(1)).to.be.true;
      expect(await worldMap.unlockedZones()).to.equal(1);
    });

    it("should keep zones 2-4 locked", async function () {
      expect(await worldMap.isZoneUnlocked(2)).to.be.false;
      expect(await worldMap.isZoneUnlocked(3)).to.be.false;
      expect(await worldMap.isZoneUnlocked(4)).to.be.false;
    });

    it("should set correct zone data", async function () {
      const z1 = await worldMap.getZone(1);
      expect(z1.name).to.equal("Lumenveil");
      expect(z1.danger).to.equal(0); // SAFE
      expect(z1.maxAgents).to.equal(100);

      const z4 = await worldMap.getZone(4);
      expect(z4.name).to.equal("Voidreach");
      expect(z4.danger).to.equal(3); // EXTREME
      expect(z4.requiredNodes).to.equal(200);
    });

    it("should have correct zone connections", async function () {
      const conn = await worldMap.getZoneConnections(2);
      expect(conn.length).to.equal(1);
      expect(conn[0]).to.equal(1); // Graymarch connects to Lumenveil
    });
  });

  describe("Zone unlocking", function () {
    it("should unlock Graymarch at 10 nodes", async function () {
      await expect(worldMap.connect(nodeRegistry).checkAndUnlock(10))
        .to.emit(worldMap, "ZoneUnlocked")
        .withArgs(2, "Graymarch", 10);
      expect(await worldMap.isZoneUnlocked(2)).to.be.true;
      expect(await worldMap.unlockedZones()).to.equal(2);
    });

    it("should unlock multiple zones at once with enough nodes", async function () {
      await worldMap.connect(nodeRegistry).checkAndUnlock(200);
      expect(await worldMap.isZoneUnlocked(2)).to.be.true;
      expect(await worldMap.isZoneUnlocked(3)).to.be.true;
      expect(await worldMap.isZoneUnlocked(4)).to.be.true;
      expect(await worldMap.unlockedZones()).to.equal(4);
    });

    it("should not unlock zones below threshold", async function () {
      await worldMap.connect(nodeRegistry).checkAndUnlock(5);
      expect(await worldMap.isZoneUnlocked(2)).to.be.false;
      expect(await worldMap.unlockedZones()).to.equal(1);
    });

    it("should revert if non-nodeRegistry calls checkAndUnlock", async function () {
      await expect(
        worldMap.connect(stranger).checkAndUnlock(100)
      ).to.be.reverted;
    });
  });

  describe("Community zones", function () {
    it("should allow admin to add new zone", async function () {
      await worldMap.addCommunityZone("Crystaldeep", "수정 심연", 2, 100, 75, [3]);
      expect(await worldMap.totalZones()).to.equal(5);
      const z5 = await worldMap.getZone(5);
      expect(z5.name).to.equal("Crystaldeep");
      expect(z5.requiredNodes).to.equal(100);
    });

    it("should revert if non-admin adds zone", async function () {
      await expect(
        worldMap.connect(stranger).addCommunityZone("Hack", "", 0, 1, 1, [])
      ).to.be.reverted;
    });
  });
});
