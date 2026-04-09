import { expect } from "chai";
import { ethers } from "hardhat";
import { deployProxy } from "./helpers";

describe("EconomyEngine", function () {
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  const BURNER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("BURNER_ROLE"));
  const COMBAT_ROLE = ethers.keccak256(ethers.toUtf8Bytes("COMBAT_ROLE"));

  it("processes death with 15% monster loot, 15% treasury loot, and xp loss", async function () {
    const [admin, combat, player, monster, treasury] = await ethers.getSigners();
    const { contract: soul } = await deployProxy("SOULToken", [admin.address]);
    const { contract: economy } = await deployProxy("EconomyEngine", [admin.address, await soul.getAddress(), treasury.address]);

    await soul.grantRole(MINTER_ROLE, admin.address);
    await soul.grantRole(MINTER_ROLE, await economy.getAddress());
    await soul.grantRole(BURNER_ROLE, await economy.getAddress());
    await economy.grantRole(COMBAT_ROLE, combat.address);

    await soul.mint(player.address, ethers.parseEther("1000"), "setup", 0);
    await economy.connect(combat).processDeath(player.address, monster.address, 1000, 77);

    expect(await soul.balanceOf(player.address)).to.equal(ethers.parseEther("700"));
    expect(await soul.balanceOf(monster.address)).to.equal(ethers.parseEther("150"));
    expect(await soul.balanceOf(treasury.address)).to.equal(ethers.parseEther("150"));
  });
});
