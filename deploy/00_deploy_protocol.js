// deploy/00_deploy_my_contract.js
const hre = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  console.log("deployer:", deployer);
  const metricToken = await deploy("MetricToken", {
    from: deployer,
    args: [deployer],
    log: true,
  });

  const chef = await deploy("Chef", {
    from: deployer,
    args: [metricToken.address],
    log: true,
  });

  try {
    await hre.run("verify:verify", {
      address: metricToken.address,
      constructorArguments: [deployer],
      contract: "src/contracts/MetricToken.sol:MetricToken",
    });
  } catch (error) {
    console.log("error:", error.message);
  }

  try {
    await hre.run("verify:verify", {
      address: chef.address,
      constructorArguments: [metricToken.address],
      contract: "src/contracts/Chef.sol:Chef",
    });
  } catch (error) {
    console.log("error:", error.message);
  }
};
module.exports.tags = ["MetricToken"];
