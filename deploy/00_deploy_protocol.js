module.exports = async (hre) => {
  const { getNamedAccounts, deployments, getChainId } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  console.log("HRE", hre.network.name);

  const metricToken = await deploy("MetricToken", {
    from: deployer,
    args: [deployer],
    log: true,
  });

  const topChef = await deploy("TopChef", {
    from: deployer,
    args: [metricToken.address],
    log: true,
  });

  if (chainId !== 31337 && hre.network.name !== "localhost") {
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
        address: topChef.address,
        constructorArguments: [metricToken.address],
        contract: "src/contracts/TopChef.sol:TopChef",
      });
    } catch (error) {
      console.log("error:", error.message);
    }
  }
};
module.exports.tags = ["MetricToken", "TopChef"];
