const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Allocator Contract", function () {
  let allocator;
  let metric;
  let owner;
  let addr1;
  let addr2;
  let addrs;

  beforeEach(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    const metricContract = await ethers.getContractFactory("MetricToken");
    metric = await metricContract.deploy();

    const allocatorContract = await ethers.getContractFactory("Allocator");
    allocator = await allocatorContract.deploy(metric.address);
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await allocator.hasRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("DISTRIBUTOR_ROLE")), owner.address)).to.equal(true);
      expect(await allocator.hasRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("DISTRIBUTOR_ROLE")), addr1.address)).to.equal(false);
    });
  });
});
