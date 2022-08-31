module.exports = async (hre) => {
  const { getNamedAccounts, deployments, getChainId } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  const xMetricToken = await deploy("Xmetric", {
    from: deployer,
    log: true,
  });

  if (chainId !== "31337" && hre.network.name !== "localhost" && hre.network.name !== "hardhat") {
    try {
      await hre.run("verify:verify", {
        address: xMetricToken.address,
        contract: "src/contracts/Xmetric.sol:Xmetric",
      });
    } catch (error) {
      console.log("error:", error.message);
    }
  }
};
module.exports.tags = ["Xmetric"];
