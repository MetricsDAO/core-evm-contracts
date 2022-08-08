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

  let tx = await vault.setCostController(actionCostController.address);
  await tx.wait();

  tx = await bountyQuestion.setQuestionApi(questionAPI.address);
  await tx.wait();

  tx = await questionStateController.setQuestionApi(questionAPI.address);
  await tx.wait();

  tx = await claimController.setQuestionApi(questionAPI.address);
  await tx.wait();

  tx = await actionCostController.setQuestionApi(questionAPI.address);
  await tx.wait();

  if (whichMetric === "Xmetric") {
    tx = await liveMetric.setTransactor(vault.address, true);
    await tx.wait();

    await liveMetric.setTransactor(actionCostController.address, true);
    await tx.wait();
  }

  tx = await actionCostController.setCreateCost(0);
  await tx.wait();

  tx = await actionCostController.setVoteCost(0);
  await tx.wait();
};
module.exports.tags = ["MVP1"];
module.exports.dependencies = ["questionAPI"];
