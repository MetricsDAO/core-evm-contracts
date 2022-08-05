const { ethers } = require("ethers");
require("dotenv").config();

const costControllerJson = require(`../deployments/${process.env.HARDHAT_NETWORK}/ActionCostController.json`);
const bountyQuestionJson = require(`../deployments/${process.env.HARDHAT_NETWORK}/BountyQuestion.json`);
const questionStateControllerJson = require(`../deployments/${process.env.HARDHAT_NETWORK}/QuestionStateController.json`);
const claimControllerJson = require(`../deployments/${process.env.HARDHAT_NETWORK}/ClaimController.json`);
const questionAPIJson = require(`../deployments/${process.env.HARDHAT_NETWORK}/QuestionAPI.json`);
const vaultJson = require(`core-evm-contracts/deployments/${process.env.NETWORK}/Vault.json`);
const xmetricJson = require(`core-evm-contracts/deployments/${process.env.NETWORK}/Xmetric.json`);

// CHANGE THIS TO WHATEVER PROVIDER YOUR USING CURRENTLY LOCALHOST/HARDHAT
const provider = new ethers.providers.JsonRpcProvider();
const signer = provider.getSigner();

async function main() {
  const bountyQuestion = new ethers.Contract(bountyQuestionJson.address, bountyQuestionJson.abi, signer);
  const questionStateController = new ethers.Contract(questionStateControllerJson.address, questionStateControllerJson.abi, signer);
  const claimController = new ethers.Contract(claimControllerJson.address, claimControllerJson.abi, signer);
  const actionCostController = new ethers.Contract(costControllerJson.address, costControllerJson.abi, signer);
  const vault = new ethers.Contract(vaultJson.address, vaultJson.abi, signer);
  const xmetric = new ethers.Contract(xmetricJson.address, xmetricJson.abi, signer);

  let tx = await vault.setCostController(costControllerJson.address);
  let receipt = await tx.wait();

  tx = await bountyQuestion.setQuestionApi(questionAPIJson.address);
  receipt = await tx.wait();

  tx = await questionStateController.setQuestionApi(questionAPIJson.address);
  receipt = await tx.wait();

  tx = await claimController.setQuestionApi(questionAPIJson.address);
  receipt = await tx.wait();

  tx = await actionCostController.setQuestionApi(questionAPIJson.address);
  receipt = await tx.wait();

  await xmetric.setTransactor(costControllerJson.address, true);
  receipt = await tx.wait();

  await xmetric.setTransactor(vaultJson.address, true);
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
