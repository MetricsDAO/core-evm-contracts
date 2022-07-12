import { ethers } from "hardhat";
import fs from "fs";

async function main() {
  const newTrasactor = "0xABF28f8D9adFB2255F4a059e37d3BcE9104969dB";

  const network = process.env.HARDHAT_NETWORK;
  console.log("adding transactor on: ", network);

  const data = await fs.readFileSync("./deployments/" + network + "/Xmetric.json", "utf8");
  const object = JSON.parse(data);
  const address = object.address;

  const MyContract = await ethers.getContractFactory("Xmetric");
  const contract = await MyContract.attach(address);

  const tx = await contract.setTransactor(newTrasactor, true);
  await tx.wait();

  console.log("done");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
