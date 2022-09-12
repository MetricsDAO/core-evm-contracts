const { ethers } = require("hardhat");
const { getContract } = require("../test/utils");

if (!process.env.metric) {
  console.error("Please set the environment variable 'metric' to a value of 'metric' or 'xmetric' to deploy the contract.");
}

module.exports = async (hre) => {
  const { getNamedAccounts, deployments, getChainId } = hre;
  const { deploy } = deployments;
  const { deployer, treasury } = await getNamedAccounts();
  const chainId = await getChainId();

  let network = hre.network.name;
  if (network === "hardhat") {
    network = "localhost";
  }
  const whichMetric = process.env.metric === "metric" ? "MetricToken" : "Xmetric";

  const liveMetric = await getContract(whichMetric);

  const bountyQuestion = await getContract("BountyQuestion");

  const vault = await getContract("Vault");

  const questionAPI = await getContract("QuestionAPI");

  const actionCostController = await getContract("ActionCostController");

  const questionStateController = await getContract("QuestionStateController");

  const claimController = await getContract("ClaimController");

  let tx = await vault.setQuestionApi(questionAPI.address);
  await tx.wait();

  tx = await bountyQuestion.setQuestionApi(questionAPI.address);
  await tx.wait();

  tx = await bountyQuestion.setQuestionApiSC(questionAPI.address);
  await tx.wait();

  tx = await questionStateController.setQuestionApi(questionAPI.address);
  await tx.wait();

  tx = await actionCostController.setQuestionApi(questionAPI.address);
  await tx.wait();

  tx = await claimController.setQuestionApi(questionAPI.address);
  await tx.wait();

  tx = await bountyQuestion.updateStateController();
  await tx.wait();

  tx = await questionStateController.updateBountyQuestion();
  await tx.wait();

  tx = await vault.updateCostController();
  await tx.wait();

  tx = await vault.updateStateController();
  await tx.wait();

  tx = await vault.updateBountyQuestion();
  await tx.wait();

  tx = await vault.updateClaimController();
  await tx.wait();

  tx = await vault.updateMetric();
  await tx.wait();

  if (whichMetric === "Xmetric") {
    tx = await liveMetric.setTransactor(vault.address, true);
    await tx.wait();

    await liveMetric.setTransactor(actionCostController.address, true);
    await tx.wait();
  }

  tx = await actionCostController.setActionCost(ethers.BigNumber.from(0), ethers.utils.parseEther("0"));
  await tx.wait();

  tx = await actionCostController.setActionCost(ethers.BigNumber.from(1), ethers.utils.parseEther("0"));
  await tx.wait();
};
module.exports.tags = ["MVP1"];
module.exports.dependencies = ["questionAPI"];
