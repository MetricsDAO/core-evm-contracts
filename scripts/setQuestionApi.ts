import fs from "fs";
import { ethers } from "hardhat";
require("dotenv").config();

async function main() {
  const network = process.env.HARDHAT_NETWORK;
  console.log("adding transactor on: ", network);

  let data = await fs.readFileSync("./deployments/" + network + "/Xmetric.json", "utf8");
  let address = JSON.parse(data).address;
  const contract = await ethers.getContractFactory("Xmetric");
  const xmetric = await contract.attach(address);

  data = await fs.readFileSync("./deployments/" + network + "/BountyQuestion.json", "utf8");
  address = JSON.parse(data).address;
  const c2 = await ethers.getContractFactory("BountyQuestion");
  const bountyQuestion = await c2.attach(address);

  data = await fs.readFileSync("./deployments/" + network + "/QuestionStateController.json", "utf8");
  address = JSON.parse(data).address;
  const c3 = await ethers.getContractFactory("QuestionStateController");
  const questionStateController = await c3.attach(address);

  data = await fs.readFileSync("./deployments/" + network + "/ClaimController.json", "utf8");
  address = JSON.parse(data).address;
  const c4 = await ethers.getContractFactory("ClaimController");
  const claimController = await c4.attach(address);

  data = await fs.readFileSync("./deployments/" + network + "/ActionCostController.json", "utf8");
  address = JSON.parse(data).address;
  const c5 = await ethers.getContractFactory("ActionCostController");
  const actionCostController = await c5.attach(address);

  data = await fs.readFileSync("./deployments/" + network + "/Vault.json", "utf8");
  address = JSON.parse(data).address;
  const c6 = await ethers.getContractFactory("Vault");
  const vault = await c6.attach(address);

  data = await fs.readFileSync("./deployments/" + network + "/QuestionAPI.json", "utf8");
  address = JSON.parse(data).address;
  const c7 = await ethers.getContractFactory("QuestionAPI");
  const questionAPI = await c7.attach(address);

  let tx = await vault.setCostController(actionCostController.address);
  let receipt = await tx.wait();

  tx = await bountyQuestion.setQuestionApi(questionAPI.address);
  receipt = await tx.wait();

  tx = await questionStateController.setQuestionApi(questionAPI.address);
  receipt = await tx.wait();

  tx = await claimController.setQuestionApi(questionAPI.address);
  receipt = await tx.wait();

  tx = await actionCostController.setQuestionApi(questionAPI.address);
  receipt = await tx.wait();

  await xmetric.setTransactor(actionCostController.address, true);
  receipt = await tx.wait();

  await xmetric.setTransactor(vault.address, true);
  receipt = await tx.wait();

  tx = await actionCostController.setCreateCost(0);
  receipt = await tx.wait();

  tx = await actionCostController.setVoteCost(0);
  receipt = await tx.wait();

  console.log("----- DONE");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
