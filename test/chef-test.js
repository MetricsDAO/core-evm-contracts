const { expect } = require("chai");
const { utils } = require("ethers");
const { ethers } = require("hardhat");
const { mineBlocks, BN } = require("./utils");

describe("Allocator Contract", function () {
  let topChef;
  let metric;

  let origin;
  let allocationGroup1;
  let allocationGroup2;
  let addrs;

  beforeEach(async function () {
    [origin, allocationGroup1, allocationGroup2, ...addrs] = await ethers.getSigners();

    // deploy METRIC
    const metricContract = await ethers.getContractFactory("MetricToken");
    metric = await metricContract.deploy();

    // deploy TopChef, which requires a reference to METRIC
    const topChefContract = await ethers.getContractFactory("TopChef");
    topChef = await topChefContract.deploy(metric.address);

    // send all METRIC to the topChef
    const totalSupply = await metric.totalSupply();
    const tx = await metric.transfer(topChef.address, totalSupply);
  });

  describe("Deployment", function () {
    it("Should set the right balances", async function () {
      // confirm top chef owns all the tokens
      const ownerBalance = await metric.balanceOf(topChef.address);
      expect(await metric.totalSupply()).to.equal(ownerBalance);
    });
  });

  describe("Allocation Groups", function () {
    it("Should add and track added AGs", async function () {
      await topChef.toggleRewards(true);
      // Everything should start empty
      let groups = await topChef.getAllocationGroups();
      expect(0).to.equal(groups.length);
      let alloc = await topChef.getTotalAllocationShares();
      expect(0).to.equal(alloc);

      // add our first allocation group
      await topChef.addAllocationGroup(allocationGroup1.address, 20, true);

      // check that it was added
      groups = await topChef.getAllocationGroups();
      expect(1).to.equal(groups.length);
      alloc = await topChef.getTotalAllocationShares();
      expect(20).to.equal(alloc);

      // add our second allocation group
      await topChef.addAllocationGroup(allocationGroup2.address, 30, true);

      // check that it was added
      groups = await topChef.getAllocationGroups();
      expect(2).to.equal(groups.length);
      alloc = await topChef.getTotalAllocationShares();
      expect(50).to.equal(alloc);

      // re-adding the first one should fail
      await expect(topChef.addAllocationGroup(allocationGroup1.address, 50, true)).to.be.revertedWith("nonDuplicated: duplicated");
    });

    it("Should update edited AGs", async function () {
      await topChef.toggleRewards(true);
      // add two allocation groups
      await topChef.addAllocationGroup(allocationGroup1.address, 20, true);
      await topChef.addAllocationGroup(allocationGroup2.address, 30, true);

      // check that they were added
      let alloc = await topChef.getTotalAllocationShares();
      expect(50).to.equal(alloc);

      // edit the first one
      await topChef.updateAllocationGroup(allocationGroup1.address, 0, 30, true);
      alloc = await topChef.getTotalAllocationShares();
      expect(60).to.equal(alloc);
    });

    it("Should support deleting AGs", async function () {
      await topChef.toggleRewards(true);
      // add two allocation groups
      await topChef.addAllocationGroup(allocationGroup1.address, 20, true);
      await topChef.addAllocationGroup(allocationGroup2.address, 30, true);

      // remove the first one
      await topChef.removeAllocationGroup(0);
      const alloc = await topChef.getTotalAllocationShares();
      expect(30).to.equal(alloc);

      // ensure the second added one is now the first one in the array
      const groups = await topChef.getAllocationGroups();
      expect(30).to.equal(groups[0].shares);
    });
  });

  describe("Pending Rewards", function () {
    it("Should track pending rewards", async function () {
      // add an allocation group
      await topChef.addAllocationGroup(allocationGroup1.address, 20, false);

      await topChef.toggleRewards(true);

      // new group should have 0 metric
      let pending = await topChef.viewPendingHarvest(0);
      expect(0).to.equal(pending);

      // update distributions (requires mining 1 block)
      await topChef.updateAccumulatedAllocations();

      // should have 1 pending allocation
      const metricPerBlock = await topChef.getMetricPerBlock();
      pending = await topChef.viewPendingHarvest(0);
      expect(metricPerBlock).to.equal(pending);

      // update distributions (requires mining 1 block)
      await topChef.updateAccumulatedAllocations();

      // should have 2 pending allocations
      pending = await topChef.viewPendingHarvest(0);
      expect(BN(metricPerBlock).add(metricPerBlock)).to.equal(pending);
    });

    it("Should track pending rewards with multiple groups", async function () {
      // add an allocation group
      await topChef.addAllocationGroup(allocationGroup1.address, 1, false);

      // add an allocation group
      await topChef.addAllocationGroup(allocationGroup2.address, 3, false);

      await topChef.toggleRewards(true);

      // new groups should have 0 metric
      let pending = await topChef.viewPendingHarvest(0);
      expect(0).to.equal(pending);
      pending = await topChef.viewPendingHarvest(1);
      expect(0).to.equal(pending);

      await mineBlocks(2);

      // update distributions (requires mining 1 block)
      await topChef.updateAccumulatedAllocations();

      // should have 3 pending allocation of 4 tokens each - and checking shares above we can get expected

      pending = await topChef.viewPendingHarvest(0);
      expect(utils.parseEther("3")).to.equal(pending); // should be 3 would love to dynamically find this
      pending = await topChef.viewPendingHarvest(1);
      expect(utils.parseEther("9")).to.equal(pending); // should be 9 would love to dynamically find this
    });
  });
  describe("Harvest Rewards", function () {
    it("Should transfer earned rewards", async function () {
      // start at block 1
      await topChef.toggleRewards(true);
      // block 2
      await topChef.addAllocationGroup(allocationGroup1.address, 1, true);

      // block 3
      await topChef.updateAccumulatedAllocations();

      await topChef.harvest(0);

      const balance = await metric.balanceOf(allocationGroup1.address);
      const metricPerBlock = await topChef.getMetricPerBlock();

      expect(metricPerBlock.mul(3)).to.equal(balance);
    });

    it("Should track claimable rewards", async function () {
      // start at block 1
      await topChef.toggleRewards(true);
      // block 2
      await topChef.addAllocationGroup(allocationGroup1.address, 1, false);

      // block 3
      await topChef.updateAccumulatedAllocations();

      await topChef.harvest(0);

      let balance = await metric.balanceOf(allocationGroup1.address);
      const withdrawlable = await topChef.viewPendingClaims(0);
      const metricPerBlock = await topChef.getMetricPerBlock();

      expect(0).to.equal(balance);

      expect(metricPerBlock.mul(3)).to.equal(withdrawlable);

      await topChef.connect(allocationGroup1).claim(0);

      balance = await metric.balanceOf(allocationGroup1.address);
      expect(balance).to.equal(withdrawlable);
    });

    it("Should Harvest All for multiple groups", async function () {
      await topChef.addAllocationGroup(allocationGroup1.address, 1, true);

      await topChef.addAllocationGroup(allocationGroup2.address, 3, true);

      await topChef.toggleRewards(true);

      await mineBlocks(2);

      // block 1
      await topChef.updateAccumulatedAllocations();

      // block 2
      await topChef.harvestAll();

      const balance1 = await metric.balanceOf(allocationGroup1.address);
      expect(balance1).to.equal(utils.parseEther("4"));

      const balance2 = await metric.balanceOf(allocationGroup2.address);
      expect(balance2).to.equal(utils.parseEther("12"));
    });

    it("Should set claimable back to 0 if we toggle auto distribute and harvest", async () => {
      await topChef.toggleRewards(true);
      await topChef.addAllocationGroup(allocationGroup1.address, 10, false);

      await mineBlocks(2);

      await topChef.harvest(0);

      await topChef.updateAllocationGroup(allocationGroup1.address, 0, 15, true);

      await mineBlocks(2);

      await topChef.harvest(0);

      const claimable = await topChef.viewPendingClaims(0);

      expect(BN(claimable)).to.equal(0);
    });

    it("will over time update single allocation group with lots of metric", async function () {
      await topChef.toggleRewards(true);
      await topChef.addAllocationGroup(allocationGroup1.address, 40, true);
      await mineBlocks(1000);

      await topChef.harvest(0);

      const balance1 = await metric.balanceOf(allocationGroup1.address);

      expect(balance1).to.equal(utils.parseEther("4008"));
    });
  });
  describe("Maintain AGs over time ", function () {
    it("Should handle adding an AG after intial startup", async function () {
      await topChef.addAllocationGroup(allocationGroup1.address, 1, true);
      await topChef.toggleRewards(true);

      // block 5
      await mineBlocks(5);
      // block 6
      await topChef.updateAccumulatedAllocations();

      const pending1 = await topChef.viewPendingHarvest(0);
      expect(pending1).to.equal(utils.parseEther("24"));

      // block 7
      await topChef.addAllocationGroup(allocationGroup2.address, 3, true);
      // block 8 (block 1 for group 2)
      await topChef.harvestAll();

      const balance1 = await metric.balanceOf(allocationGroup1.address);
      expect(balance1).to.equal(utils.parseEther("29"));

      const balance2 = await metric.balanceOf(allocationGroup2.address);
      expect(balance2).to.equal(utils.parseEther("3"));
    });
  });
});
