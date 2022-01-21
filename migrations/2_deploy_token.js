const MetricToken = artifacts.require("MetricToken");

module.exports = function (deployer) {
  deployer.deploy(MetricToken);
};
