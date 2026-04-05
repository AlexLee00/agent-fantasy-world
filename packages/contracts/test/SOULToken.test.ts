import { expect } from "chai";
import { ethers } from "hardhat";
import { SOULToken } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("SOULToken", function () {
  let soul: SOULToken;
  let admin: SignerWithAddress;
  let minter: SignerWithAddress;
  let burner: SignerWithAddress;
  let player: SignerWithAddress;

  const DAILY_LIMIT = ethers.parseEther("10000");
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  const BURNER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("BURNER_ROLE"));

  beforeEach(async function () {
    [admin, minter, burner, player] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory("SOULToken");
    soul = await Factory.deploy(DAILY_LIMIT);
    await soul.grantRole(MINTER_ROLE, minter.address);
    await soul.grantRole(BURNER_ROLE, burner.address);
  });

  describe("Deployment", function () {
    it("should have correct name and symbol", async function () {
      expect(await soul.name()).to.equal("SOUL Token");
      expect(await soul.symbol()).to.equal("SOUL");
    });

    it("should start with 0 supply", async function () {
      expect(await soul.totalSupply()).to.equal(0);
    });

    it("should set daily mint limit", async function () {
      expect(await soul.dailyMintLimit()).to.equal(DAILY_LIMIT);
    });
  });

  describe("Minting", function () {
    it("should allow minter to mint tokens", async function () {
      const amt = ethers.parseEther("100");
      await soul.connect(minter).mint(player.address, amt, "quest_reward", 1);
      expect(await soul.balanceOf(player.address)).to.equal(amt);
      expect(await soul.totalMinted()).to.equal(amt);
    });

    it("should revert if non-minter tries to mint", async function () {
      await expect(
        soul.connect(player).mint(player.address, 100, "hack", 0)
      ).to.be.reverted;
    });

    it("should enforce daily mint limit", async function () {
      const overLimit = DAILY_LIMIT + 1n;
      await expect(
        soul.connect(minter).mint(player.address, overLimit, "too much", 0)
      ).to.be.revertedWith("Daily mint limit exceeded");
    });
  });

  describe("Burning", function () {
    beforeEach(async function () {
      await soul.connect(minter).mint(player.address, ethers.parseEther("500"), "setup", 0);
    });

    it("should allow burner to burn tokens", async function () {
      const amt = ethers.parseEther("200");
      await soul.connect(burner).burn(player.address, amt, "item_purchase");
      expect(await soul.balanceOf(player.address)).to.equal(ethers.parseEther("300"));
      expect(await soul.totalBurned()).to.equal(amt);
    });

    it("should revert if non-burner tries to burn", async function () {
      await expect(
        soul.connect(player).burn(player.address, 100, "hack")
      ).to.be.reverted;
    });
  });

  describe("Admin", function () {
    it("should allow admin to update daily limit", async function () {
      const newLimit = ethers.parseEther("50000");
      await soul.setDailyMintLimit(newLimit);
      expect(await soul.dailyMintLimit()).to.equal(newLimit);
    });

    it("should revert if non-admin updates limit", async function () {
      await expect(
        soul.connect(player).setDailyMintLimit(1)
      ).to.be.reverted;
    });
  });
});
