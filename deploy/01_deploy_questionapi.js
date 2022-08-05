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

  const vault = await deploy("Vault", {
    from: deployer,
    args: [whichMetricAddress, questionStateController.address, "0xD3603df4BC1A9df587155bc03eeb166874d6077C"],
    log: true,
  });

  const actionCostController = await deploy("ActionCostController", {
    from: deployer,
    args: [whichMetricAddress, vault.address],
    log: true,
  });

  const questionAPI = await deploy("QuestionAPI", {
    from: deployer,
    args: [bountyQuestion.address, questionStateController.address, claimController.address, actionCostController.address],
    log: true,
  });

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
        constructorArguments: [whichMetricAddress],
        contract: "src/contracts/Protocol/ActionCostController.sol:ActionCostController",
      });
    } catch (error) {
      console.log("error:", error.message);
    }

    try {
      await hre.run("verify:verify", {
        address: questionAPI.address,
        constructorArguments: [bountyQuestion.address, claimController.address, questionStateController.address, actionCostController.address],
        contract: "src/contracts/Protocol/QuestionAPI.sol:QuestionAPI",
      });
    } catch (error) {
      console.log("error:", error.message);
    }

    try {
      await hre.run("verify:verify", {
        address: vault.address,
        constructorArguments: [whichMetricAddress, questionStateController.address, "0xD3603df4BC1A9df587155bc03eeb166874d6077C"],
        contract: "src/contracts/Protocol/Vault.sol:Vault",
      });
    } catch (error) {
      console.log("error:", error.message);
    }
  }
};
module.exports.tags = ["QuestionAPI"];
module.exports.dependencies = ["BountyQuestion", "QuestionStateController", "Vault", "ClaimController", "ActionCostController"];
