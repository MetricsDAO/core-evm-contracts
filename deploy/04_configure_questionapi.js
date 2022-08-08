module.exports = async (hre) => {
  const { getNamedAccounts, deployments, getChainId } = hre;
  const { deploy } = deployments;
  const { deployer, treasury } = await getNamedAccounts();
  const chainId = await getChainId();

  const whichMetric = process.env.metric === "metric" ? "MetricToken" : "Xmetric";
  let network = hre.network.name;
  if (network === "hardhat") {
    network = "localhost";
  }
  console.log("huh");
  const { address: whichMetricAddress } = require(`../deployments/${network}/${whichMetric}.json`);

  const bountyQuestionDeployment = await deployments.get("BountyQuestion");
  const bountyQuestion = await hre.ethers.getContractAt("BountyQuestion", bountyQuestionDeployment.address);

  const vaultDeployment = await deployments.get("Vault");
  const vault = await hre.ethers.getContractAt("Vault", vaultDeployment.address);

  const questionApiDeployment = await deployments.get("QuestionAPI");
  const questionAPI = await hre.ethers.getContractAt("QuestionAPI", questionApiDeployment.address);

  const actionCostDeployment = await deployments.get("ActionCostController");
  const actionCostController = await hre.ethers.getContractAt("ActionCostController", actionCostDeployment.address);

  const questionStateDeployment = await deployments.get("QuestionStateController");
  const questionStateController = await hre.ethers.getContractAt("QuestionStateController", questionStateDeployment.address);

  const claimDeployment = await deployments.get("ClaimController");
  const claimController = await hre.ethers.getContractAt("ClaimController", claimDeployment.address);

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
    const xmetric = await hre.ethers.getContractAt("Xmetric", whichMetricAddress);
    // tx = await xmetric.setTransactor(vault.address, true);
    // await tx.wait();

    // await xmetric.setTransactor(actionCostDeployment.address, true);
    // await tx.wait();
  }

  tx = await actionCostController.setCreateCost(0);
  await tx.wait();

  tx = await actionCostController.setVoteCost(0);
  await tx.wait();

  console.log("----- DONE");
};
module.exports.tags = ["MVP1"];
module.exports.dependencies = ["questionAPI"];
