const { expect } = require("chai");
const { utils } = require("ethers");
const { ethers, network } = require("hardhat");
const { mineBlocks, BN, add } = require("./utils");

describe("Allocator Contract", async function () {
  let topChef;
  let metric;

  let origin;
  let allocationGroup1;
  let allocationGroup2;
  let addrs;

  beforeEach(async function () {
    [origin, allocationGroup1, allocationGroup2, ...addrs] = await ethers.getSigners();
    // Set To TRUE as tests are based on hardhat.config
    await network.provider.send("evm_setAutomine", [true]);

    // deploy METRIC
    const metricContract = await ethers.getContractFactory("MetricToken");
    metric = await metricContract.deploy();

    // deploy TopChef, which requires a reference to METRIC
    const topChefContract = await ethers.getContractFactory("TopChef");
    topChef = await topChefContract.deploy(metric.address);

    // send all METRIC to the topChef
    const totalSupply = await metric.totalSupply();
    await metric.transfer(topChef.address, totalSupply);
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
      await topChef.addAllocationGroup(allocationGroup1.address, 20);

      // check that it was added
      groups = await topChef.getAllocationGroups();
      expect(1).to.equal(groups.length);
      alloc = await topChef.getTotalAllocationShares();
      expect(20).to.equal(alloc);

      // add our second allocation group
      await topChef.addAllocationGroup(allocationGroup2.address, 30);

      // check that it was added
      groups = await topChef.getAllocationGroups();
      expect(2).to.equal(groups.length);
      alloc = await topChef.getTotalAllocationShares();
      expect(50).to.equal(alloc);

      // re-adding the first one should fail
      await expect(topChef.addAllocationGroup(allocationGroup1.address, 50)).to.be.revertedWith("DuplicateAddress()");
    });

    it("Should update edited AGs", async function () {
      await topChef.toggleRewards(true);
      // add two allocation groups
      await topChef.addAllocationGroup(allocationGroup1.address, 20);
      await topChef.addAllocationGroup(allocationGroup2.address, 30);

      // check that they were added
      let alloc = await topChef.getTotalAllocationShares();
      expect(50).to.equal(alloc);

      // edit the first one
      await topChef.updateAllocationGroup(allocationGroup1.address, 0, 30);
      alloc = await topChef.getTotalAllocationShares();
      expect(60).to.equal(alloc);
    });

    it("Should support deleting AGs", async function () {
      await topChef.toggleRewards(true);
      // add two allocation groups
      await topChef.addAllocationGroup(allocationGroup1.address, 20);
      await topChef.addAllocationGroup(allocationGroup2.address, 30);

      // remove the first one
      await topChef.removeAllocationGroup(0);
      const alloc = await topChef.getTotalAllocationShares();
      expect(30).to.equal(alloc);

      // ensure the second added one is now the first one in the array
      const groups = await topChef.getAllocationGroups();
      expect(30).to.equal(groups[0].shares);
    });

    it("Removing an AG with pending rewards should claim them", async function () {
      await topChef.toggleRewards(true);

      // add two allocation groups
      await topChef.addAllocationGroup(allocationGroup1.address, 20);

      // remove the first one and ensure they got their rewards

      const pendingBalance = await topChef.connect(allocationGroup1).viewPendingRewards(0);
      await topChef.removeAllocationGroup(0);
      const actualBalance = await metric.balanceOf(allocationGroup1.address);
      expect(actualBalance).to.equal(add(pendingBalance, ethers.utils.parseEther("4")));
    });
  });

  describe("Pending Rewards", function () {
    it("Should track pending rewards", async function () {
      // add an allocation group
      await topChef.addAllocationGroup(allocationGroup1.address, 20);

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
      await topChef.addAllocationGroup(allocationGroup1.address, 1);

      // add an allocation group
      await topChef.addAllocationGroup(allocationGroup2.address, 3);

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
      await topChef.addAllocationGroup(allocationGroup1.address, 1);

      // block 3
      await topChef.updateAccumulatedAllocations();

      await topChef.connect(allocationGroup1).claim(0);

      const balance = await metric.balanceOf(allocationGroup1.address);
      const metricPerBlock = await topChef.getMetricPerBlock();

      expect(metricPerBlock.mul(3)).to.equal(balance);
    });

    it("Should track claimable rewards", async function () {
      // start at block 1
      await topChef.toggleRewards(true);
      // block 2
      await topChef.addAllocationGroup(allocationGroup1.address, 1);

      // block 3
      await topChef.updateAccumulatedAllocations();

      await topChef.harvest(0);

      let balance = await metric.balanceOf(allocationGroup1.address);
      const withdrawlable = await topChef.viewPendingClaims(0);
      const metricPerBlock = await topChef.getMetricPerBlock();

      expect(0).to.equal(balance);

      // TODO why is this flakey
      // expect(metricPerBlock.mul(3)).to.equal(withdrawlable);

      await mineBlocks(100);

      const pendingEstimateHarvestPlusPendingClaims = await topChef.viewPendingRewards(0);

      await topChef.connect(allocationGroup1).claim(0);

      balance = await metric.balanceOf(allocationGroup1.address);
      // so pending harvest + pending claims plus metric per block * 1 as harvest creates another block
      expect(balance).to.equal(pendingEstimateHarvestPlusPendingClaims.add(metricPerBlock.mul(1)));
    });

    it("Should Harvest All for multiple groups", async function () {
      await topChef.addAllocationGroup(allocationGroup1.address, 1);

      await topChef.addAllocationGroup(allocationGroup2.address, 3);

      await topChef.toggleRewards(true);

      await mineBlocks(2);

      // block 2
      await topChef.harvestAll();

      await topChef.connect(allocationGroup1).claim(0);
      await topChef.connect(allocationGroup2).claim(1);

      const balance1 = await metric.balanceOf(allocationGroup1.address);
      expect(balance1).to.equal(utils.parseEther("4"));

      const balance2 = await metric.balanceOf(allocationGroup2.address);
      expect(balance2).to.equal(utils.parseEther("15"));
    });

    it("will over time update single allocation group with lots of metric", async function () {
      await topChef.toggleRewards(true);
      await topChef.addAllocationGroup(allocationGroup1.address, 40);
      await mineBlocks(100);

      await topChef.connect(allocationGroup1).claim(0);

      const balance1 = await metric.balanceOf(allocationGroup1.address);

      expect(balance1).to.equal(utils.parseEther("408"));
    });
  });
  describe("Maintain AGs over time ", function () {
    it("Should handle adding an AG after intial startup", async function () {
      await topChef.addAllocationGroup(allocationGroup1.address, 1);
      await topChef.toggleRewards(true);

      // block 5
      await mineBlocks(5);
      // block 6
      await topChef.updateAccumulatedAllocations();

      const pending1 = await topChef.viewPendingHarvest(0);
      expect(pending1).to.equal(utils.parseEther("24"));

      // one more block 24 + 4
      await topChef.connect(allocationGroup1).claim(0);

      const balance1 = await metric.balanceOf(allocationGroup1.address);
      expect(balance1).to.equal(utils.parseEther("28"));

      await topChef.addAllocationGroup(allocationGroup2.address, 3);
      await topChef.connect(allocationGroup2).claim(1);

      const balance2 = await metric.balanceOf(allocationGroup2.address);
      expect(balance2).to.equal(utils.parseEther("3"));
    });
  });
});
