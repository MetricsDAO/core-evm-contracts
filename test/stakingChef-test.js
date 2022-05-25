const { expect } = require("chai");
const { utils } = require("ethers");
const { ethers } = require("hardhat");
const { mineBlocks, BN } = require("./utils");

describe("Staking Contract", function () {
  let stakingChef;
  let metric;

  let staker1;
  let staker2;
  let vestingContract;

  beforeEach(async function () {
    [staker1, staker2, vestingContract] = await ethers.getSigners();

    // deploy METRIC
    const metricContract = await ethers.getContractFactory("MetricToken");
    metric = await metricContract.deploy(vestingContract.address);

    // deploy StakingChef, which requires a reference to METRIC
    const stakingChefContract = await ethers.getContractFactory("StakingChef");
    stakingChef = await stakingChefContract.deploy(metric.address);

    // send all METRIC to the stakingChef
    const metricTokenConnectedToVestingContract = await metric.connect(vestingContract);
    await metricTokenConnectedToVestingContract.transfer(stakingChef.address, await metric.totalSupply());
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      // confirm top chef owns all the tokens - this will change with staking chef most likely
      const ownerBalance = await metric.balanceOf(stakingChef.address);
      expect(await metric.totalSupply()).to.equal(ownerBalance);
    });
  });

  describe("Staking", function () {
    it("Should add and track added Stakes", async function () {
      await stakingChef.toggleRewards(true);
      // Everything should start empty
      let stakes = await stakingChef.getStakes();
      expect(0).to.equal(stakes.length);
      let alloc = await stakingChef.getTotalAllocationPoints();
      expect(0).to.equal(alloc);

      // add our first stake
      await stakingChef.stakeMetric(staker1.address, 20, 1);

      // check that it was added
      groups = await stakingChef.getStakes();
      expect(1).to.equal(groups.length);
      alloc = await stakingChef.getTotalAllocationPoints();
      expect(20).to.equal(alloc);

      // add our second allocation group
      await stakingChef.stakeMetric(allocationGroup2.address, 30, 1);

      // check that it was added
      groups = await stakingChef.getStakes();
      expect(2).to.equal(groups.length);
      alloc = await stakingChef.getTotalAllocationPoints();
      expect(50).to.equal(alloc);

      // re-adding the first one should fail
      await expect(stakingChef.stakeMetric(staker1.address, 50, 1)).to.be.revertedWith("nonDuplicated: duplicated");
    });

    it("Should update edited Stakes", async function () {
      await stakingChef.toggleRewards(true);
      // add two allocation groups
      await stakingChef.stakeMetric(staker1.address, 20, 1);
      await stakingChef.stakeMetric(staker2.address, 30, 1);

      // check that they were added
      let alloc = await stakingChef.getTotalAllocationPoints();
      expect(50).to.equal(alloc);

      // edit the first one
      await stakingChef.updateAllocationGroup(staker1.address, 0, 30, 1);
      alloc = await stakingChef.getTotalAllocationPoints();
      expect(60).to.equal(alloc);
    });

    it("Should support deleting AGs", async function () {
      await stakingChef.toggleRewards(true);
      // add two allocation groups
      await stakingChef.stakeMetric(staker1.address, 20, 1);
      await stakingChef.stakeMetric(staker2.address, 30, 1);

      // remove the first one
      await stakingChef.removeAllocationGroup(0);
      const alloc = await stakingChef.getTotalAllocationPoints();
      expect(30).to.equal(alloc);

      // ensure the second added one is now the first one in the array
      const groups = await stakingChef.getStakes();
      expect(30).to.equal(groups[0].shares);
    });
  });

  describe("Pending Rewards", function () {
    it("Should track pending rewards", async function () {
      // add an allocation group
      await stakingChef.stakeMetric(staker1.address, 20, 1);

      await stakingChef.toggleRewards(true);

      // new group should have 0 metric
      let pending = await stakingChef.viewPendingHarvest(0);
      expect(0).to.equal(pending);

      // update distributions (requires mining 1 block)
      await stakingChef.updateAccumulatedAllocations();

      // should have 1 pending allocation
      const metricPerBlock = await stakingChef.getMetricPerBlock();
      pending = await stakingChef.viewPendingHarvest(0);
      expect(metricPerBlock).to.equal(pending);

      // update distributions (requires mining 1 block)
      await stakingChef.updateAccumulatedAllocations();

      // should have 2 pending allocations
      pending = await stakingChef.viewPendingHarvest(0);
      expect(BN(metricPerBlock).add(metricPerBlock)).to.equal(pending);
    });

    it("Should track pending rewards with multiple stakes", async function () {
      // add an allocation group
      await stakingChef.stakeMetric(staker1.address, 1, 1);

      // add a stake
      await stakingChef.stakeMetric(staker2.address, 3, 1);

      await stakingChef.toggleRewards(true);

      // new groups should have 0 metric
      let pending = await stakingChef.viewPendingHarvest(0);
      expect(0).to.equal(pending);
      pending = await stakingChef.viewPendingHarvest(1);
      expect(0).to.equal(pending);

      await mineBlocks(2);

      // update distributions (requires mining 1 block)
      await stakingChef.updateAccumulatedAllocations();

      // should have 3 pending allocation of 4 tokens each - and checking shares above we can get expected

      pending = await stakingChef.viewPendingHarvest(0);
      expect(utils.parseEther("3")).to.equal(pending); // should be 3 would love to dynamically find this
      pending = await stakingChef.viewPendingHarvest(1);
      expect(utils.parseEther("9")).to.equal(pending); // should be 9 would love to dynamically find this
    });
  });

  describe("Harvest Rewards", function () {
    it("Should transfer earned rewards", async function () {
      // start at block 1
      await stakingChef.toggleRewards(true);
      // block 2
      await stakingChef.stakeMetric(staker1.address, 1, 1);

      // block 3
      await stakingChef.updateAccumulatedAllocations();

      await stakingChef.harvest(0);

      const balance = await metric.balanceOf(staker1.address);
      const metricPerBlock = await stakingChef.getMetricPerBlock();

      expect(metricPerBlock.mul(3)).to.equal(balance);
    });

    it("Should track claimable rewards", async function () {
      // start at block 1
      await stakingChef.toggleRewards(true);
      // block 2
      await stakingChef.stakeMetric(staker1.address, 1, 1);

      // block 3
      await stakingChef.updateAccumulatedAllocations();

      await stakingChef.harvest(0);

      let balance = await metric.balanceOf(staker1.address);
      const withdrawlable = await stakingChef.viewPendingClaims(0);
      const metricPerBlock = await stakingChef.getMetricPerBlock();

      expect(0).to.equal(balance);

      expect(metricPerBlock.mul(3)).to.equal(withdrawlable);

      await stakingChef.connect(staker1).claim(0);

      balance = await metric.balanceOf(staker1.address);
      expect(balance).to.equal(withdrawlable);
    });
  });

  describe("Maintain Stakes over time ", function () {
    it("Should handle adding a stake after intial startup", async function () {
      await stakingChef.stakeMetric(staker1.address, 1, 1);
      await stakingChef.toggleRewards(true);

      // block 5
      await mineBlocks(5);
      // block 6
      await stakingChef.updateAccumulatedStakingRewards();

      const pending1 = await stakingChef.viewPendingHarvest(0);
      expect(pending1).to.equal(utils.parseEther("24"));

      // block 7
      await stakingChef.stakeMetric(staker2.address, 3, 1);
      // block 8 (block 1 for group 2)
      await stakingChef.harvestAll();

      const balance1 = await metric.balanceOf(staker1.address);
      expect(balance1).to.equal(utils.parseEther("29"));

      const balance2 = await metric.balanceOf(staker2.address);
      expect(balance2).to.equal(utils.parseEther("3"));
    });
  });
});
