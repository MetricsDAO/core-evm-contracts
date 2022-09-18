const { getContract } = require("../test/utils");

const whichMetric = process.env.metric === "metric" ? "MetricToken" : "Xmetric";

module.exports = async (hre) => {
  const { getNamedAccounts, deployments, getChainId } = hre;
  const { deploy } = deployments;
  const { deployer, treasury } = await getNamedAccounts();
  const chainId = await getChainId();

  let network = hre.network.name;
  if (network === "hardhat") {
    network = "localhost";
  }

  const metaData = await deploy("MetadataController", {
    from: deployer,
    log: true,
  });

  if (chainId !== "31337" && hre.network.name !== "localhost" && hre.network.name !== "hardhat") {
    try {
      await hre.run("verify:verify", {
        address: metaData.address,
        contract: "src/contracts/Protocol/MetadataController.sol:MetadataController",
      });
    } catch (error) {
      console.log("error:", error.message);
    }
  }
};
module.exports.tags = ["questionAPI"];
module.exports.dependencies = ["Xmetric", "MetricToken"];
