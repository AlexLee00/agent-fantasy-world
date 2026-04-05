import { expect } from "chai";
import { ethers } from "hardhat";
import { AFWToken } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("AFWToken", function () {
  let token: AFWToken;
  let owner: SignerWithAddress;
  let mining: SignerWithAddress;
  let community: SignerWithAddress;
  let team: SignerWithAddress;
  let ecosystem: SignerWithAddress;
  let liquidity: SignerWithAddress;
  let advisor: SignerWithAddress;
  let user: SignerWithAddress;

  const TOTAL = ethers.parseEther("1000000000");

  beforeEach(async function () {
    [owner, mining, community, team, ecosystem, liquidity, advisor, user] =
      await ethers.getSigners();
    const Factory = await ethers.getContractFactory("AFWToken");
    token = await Factory.deploy(
      mining.address, community.address, team.address,
      ecosystem.address, liquidity.address, advisor.address
    );
  });

  describe("Deployment", function () {
    it("should have correct name and symbol", async function () {
      expect(await token.name()).to.equal("Agent Fantasy World");
      expect(await token.symbol()).to.equal("AFW");
    });

    it("should mint exactly 1B total supply", async function () {
      expect(await token.totalSupply()).to.equal(TOTAL);
    });

    it("should distribute tokens correctly", async function () {
      expect(await token.balanceOf(mining.address)).to.equal(ethers.parseEther("400000000"));
      expect(await token.balanceOf(community.address)).to.equal(ethers.parseEther("250000000"));
      expect(await token.balanceOf(team.address)).to.equal(ethers.parseEther("150000000"));
      expect(await token.balanceOf(ecosystem.address)).to.equal(ethers.parseEther("100000000"));
      expect(await token.balanceOf(liquidity.address)).to.equal(ethers.parseEther("50000000"));
      expect(await token.balanceOf(advisor.address)).to.equal(ethers.parseEther("50000000"));
    });

    it("should store pool addresses", async function () {
      expect(await token.nodeMiningPool()).to.equal(mining.address);
      expect(await token.communityPool()).to.equal(community.address);
    });
  });

  describe("Fixed supply", function () {
    it("should revert on mint attempt", async function () {
      await expect(token.mint(user.address, 1)).to.be.revertedWith("AFW: fixed supply");
    });
  });

  describe("Burn", function () {
    it("should allow owner to burn for protocol", async function () {
      const amt = ethers.parseEther("1000");
      // Transfer some tokens to owner first
      await token.connect(mining).transfer(owner.address, amt);
      await token.burnForProtocol(amt, "protocol fee");
      expect(await token.totalBurned()).to.equal(amt);
      expect(await token.totalSupply()).to.equal(TOTAL - amt);
    });

    it("should revert if non-owner tries to burn", async function () {
      await expect(
        token.connect(user).burnForProtocol(100, "hack")
      ).to.be.reverted;
    });
  });

  describe("Transfer", function () {
    it("should allow normal ERC20 transfers", async function () {
      const amt = ethers.parseEther("500");
      await token.connect(mining).transfer(user.address, amt);
      expect(await token.balanceOf(user.address)).to.equal(amt);
    });
  });
});
