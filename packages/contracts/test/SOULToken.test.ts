import { expect } from "chai";
import { ethers } from "hardhat";
import { deployProxy } from "./helpers";

describe("SOULToken", function () {
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  const BURNER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("BURNER_ROLE"));

  it("has correct metadata and starts with 0 supply", async function () {
    const [admin] = await ethers.getSigners();
    const { contract: soul } = await deployProxy("SOULToken", [admin.address]);

    expect(await soul.name()).to.equal("SOUL Token");
    expect(await soul.symbol()).to.equal("SOUL");
    expect(await soul.totalSupply()).to.equal(0);
  });

  it("allows minters to mint without daily limit", async function () {
    const [admin, minter, player] = await ethers.getSigners();
    const { contract: soul } = await deployProxy("SOULToken", [admin.address]);

    await soul.grantRole(MINTER_ROLE, minter.address);
    const amt = ethers.parseEther("2000000");
    await soul.connect(minter).mint(player.address, amt, "quest_reward", 1);

    expect(await soul.balanceOf(player.address)).to.equal(amt);
    expect(await soul.totalMinted()).to.equal(amt);
  });

  it("allows burners to burn tokens", async function () {
    const [admin, burner, player] = await ethers.getSigners();
    const { contract: soul } = await deployProxy("SOULToken", [admin.address]);

    await soul.grantRole(MINTER_ROLE, admin.address);
    await soul.grantRole(BURNER_ROLE, burner.address);
    await soul.mint(player.address, ethers.parseEther("500"), "setup", 0);
    await soul.connect(burner).burn(player.address, ethers.parseEther("200"), "item_purchase");

    expect(await soul.balanceOf(player.address)).to.equal(ethers.parseEther("300"));
    expect(await soul.totalBurned()).to.equal(ethers.parseEther("200"));
  });
});
