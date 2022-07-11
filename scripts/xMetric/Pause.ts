import { ethers } from "hardhat";
import fs from "fs";

async function main() {
  const network = process.env.HARDHAT_NETWORK;
  console.log("Pausing on: ", network);

  const data = await fs.readFileSync("./deployments/" + network + "/Xmetric.json", "utf8");
  const object = JSON.parse(data);
  const address = object.address;
  console.log("address: " + address);

  const MyContract = await ethers.getContractFactory("Xmetric");
  const contract = await MyContract.attach(address);

  const tx = await contract.pause();
  await tx.wait();

  console.log("done");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
