import fs from "fs";
import { ethers } from "hardhat";

module.exports = async (hre) => {
  const { getNamedAccounts, deployments, getChainId } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  const whichMetric = process.env.metric === "metric" ? "MetricToken" : "Xmetric";
  let network = hre.network.name;
  if (network === "hardhat") {
    network = "localhost";
  }

  const { address: whichMetricAddress } = require(`../deployments/${network}/${whichMetric}.json`);

  const bountyQuestion = await deploy("BountyQuestion", {
    from: deployer,
    log: true,
  });

  const claimController = await deploy("ClaimController", {
    from: deployer,
    log: true,
  });

  const questionStateController = await deploy("QuestionStateController", {
    from: deployer,
    log: true,
  });

  const actionCostController = await deploy("ActionCostController", {
    from: deployer,
    args: [whichMetricAddress],
    log: true,
  });

  const questionAPI = await deploy("QuestionAPI", {
    from: deployer,
    args: [bountyQuestion.address, claimController.address, questionStateController.address, actionCostController.address],
    log: true,
  });

  let tx = await bountyQuestion.setQuestionApi(questionAPI.address);
  let receipt = await tx.wait();

  tx = questionStateController.setQuestionApi(questionAPI.address);
  receipt = await tx.wait();

  tx = claimController.setQuestionApi(questionAPI.address);
  receipt = await tx.wait();

  tx = actionCostController.setQuestionApi(questionAPI.address);
  receipt = await tx.wait();

  console.log("------");
  console.log("------ If using xMetricToken, go and add the actionCostController as a transactor ");
  console.log("------");

  if (chainId !== "31337" && hre.network.name !== "localhost" && hre.network.name !== "hardhat") {
    try {
      await hre.run("verify:verify", {
        address: bountyQuestion.address,
        contract: "src/contracts/Protocol/BountyQuestion.sol:BountyQuestion",
      });
    } catch (error) {
      console.log("error:", error.message);
    }

    try {
      await hre.run("verify:verify", {
        address: claimController.address,
        contract: "src/contracts/Protocol/ActionCostController.sol:ActionCostController",
      });
    } catch (error) {
      console.log("error:", error.message);
    }

    try {
      await hre.run("verify:verify", {
        address: questionStateController.address,
        contract: "src/contracts/Protocol/QuestionStateController.sol:QuestionStateController",
      });
    } catch (error) {
      console.log("error:", error.message);
    }

    try {
      await hre.run("verify:verify", {
        address: actionCostController.address,
        constructorArguments: [matricAddress],
        contract: "src/contracts/Protocol/QuestionStateController.sol:QuestionStateController",
      });
    } catch (error) {
      console.log("error:", error.message);
    }

    try {
      await hre.run("verify:verify", {
        address: questionAPI.address,
        constructorArguments: [bountyQuestion.address, claimController.address, questionStateController.address, actionCostController.address],
        contract: "src/contracts/StakingChef.sol:StakingChef",
      });
    } catch (error) {
      console.log("error:", error.message);
    }
  }
};
module.exports.tags = ["QuestionAPI"];
module.exports.dependencies = ["BountyQuestion", "ClaimController", "QuestionStateController", "ActionCostController"];
