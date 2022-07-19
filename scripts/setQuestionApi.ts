const { ethers } = require("ethers");
require("dotenv").config();

const costControllerJson = require(`../deployments/${process.env.NETWORK}/ActionCostController.json`);
const bountyQuestionJson = require(`../deployments/${process.env.NETWORK}/BountyQuestion.json`);
const questionStateControllerJson = require(`../deployments/${process.env.NETWORK}/QuestionStateController.json`);
const claimControllerJson = require(`../deployments/${process.env.NETWORK}/ClaimController.json`);
const questionAPIJson = require(`../deployments/${process.env.NETWORK}/QuestionAPI.json`);

// CHANGE THIS TO WHATEVER PROVIDER YOUR USING CURRENTLY LOCALHOST/HARDHAT
const provider = new ethers.providers.JsonRpcProvider();
const signer = provider.getSigner();

async function init() {
  const bountyQuestion = new ethers.Contract(bountyQuestionJson.address, bountyQuestionJson.abi, signer);
  const questionStateController = new ethers.Contract(questionStateControllerJson.address, questionStateControllerJson.abi, signer);
  const claimController = new ethers.Contract(claimControllerJson.address, claimControllerJson.abi, signer);
  const actionCostController = new ethers.Contract(costControllerJson.address, costControllerJson.abi, signer);

  let tx = await bountyQuestion.setQuestionApi(questionAPIJson.address);
  let receipt = await tx.wait();

  tx = await questionStateController.setQuestionApi(questionAPIJson.address);
  receipt = await tx.wait();

  tx = await claimController.setQuestionApi(questionAPIJson.address);
  receipt = await tx.wait();

  tx = await actionCostController.setQuestionApi(questionAPIJson.address);
  receipt = await tx.wait();

  console.log(receipt);
}

init();
