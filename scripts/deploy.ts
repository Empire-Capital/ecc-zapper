import { ethers } from "hardhat";

const empireRouter = 0x0;

async function main() {
  const EccZapper = await ethers.getContractFactory("EccZapper");
  const eccZapper = await EccZapper.deploy(empireRouter);
  await eccZapper.deployed();
  console.log("EccZapper deployed to:", eccZapper.address);
}

main().catch((error) => {
  console.error(error);
});