import { ethers } from "hardhat";

export async function deployProxy(contractName: string, initArgs: any[] = []) {
  const factory = await ethers.getContractFactory(contractName);
  const implementation = await factory.deploy();
  await implementation.waitForDeployment();

  const proxyFactory = await ethers.getContractFactory("AFWUUPSProxy");
  const initData = factory.interface.encodeFunctionData("initialize", initArgs);
  const proxy = await proxyFactory.deploy(await implementation.getAddress(), initData);
  await proxy.waitForDeployment();

  return {
    implementation,
    proxy,
    address: await proxy.getAddress(),
    contract: await ethers.getContractAt(contractName, await proxy.getAddress()),
  };
}

export const fixedClass = (hp: number, mp: number, attack: number, defense: number, speed: number) => ({
  hp,
  maxHp: hp,
  mp,
  maxMp: mp,
  attack,
  defense,
  speed,
});

export async function seedAgentRegistry(registry: any) {
  await registry.registerClass("Warrior", fixedClass(100, 50, 20, 15, 10), fixedClass(100, 50, 20, 15, 10));
  await registry.registerClass("Mage", fixedClass(70, 120, 25, 8, 12), fixedClass(70, 120, 25, 8, 12));
  await registry.registerClass("Ranger", fixedClass(80, 60, 18, 12, 16), fixedClass(80, 60, 18, 12, 16));
  await registry.registerClass("Healer", fixedClass(75, 100, 10, 10, 11), fixedClass(75, 100, 10, 10, 11));
  await registry.registerClass("Tank", fixedClass(150, 30, 12, 25, 7), fixedClass(150, 30, 12, 25, 7));

  await registry.registerStatus("ALIVE", false);
  await registry.registerStatus("DEAD", true);
  await registry.registerStatus("RESTING", false);
  await registry.registerStatus("IN_COMBAT", false);
  await registry.registerStatus("TRAVELING", false);
}

export async function seedWorldMap(worldMap: any) {
  await worldMap.registerDangerLevel("SAFE", 1, 10);
  await worldMap.registerDangerLevel("MEDIUM", 11, 25);
  await worldMap.registerDangerLevel("DANGER", 26, 50);
  await worldMap.registerDangerLevel("EXTREME", 51, 99);

  await worldMap.registerZone("Lumenveil", "빛의 베일", 1, 1, 100, []);
  await worldMap.registerZone("Graymarch", "회색 행진", 2, 10, 200, [1]);
  await worldMap.registerZone("Embervault", "잿불 지하", 3, 50, 150, [2]);
  await worldMap.registerZone("Voidreach", "공허의 끝", 4, 200, 50, [3]);
}
