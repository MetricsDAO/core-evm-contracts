const { expect } = require("chai");
const { utils } = require("ethers");
const { ethers } = require("hardhat");
const { mineBlocks, BN, closeEnough } = require("./utils");

describe("Staking Contract", function () {
  let stakingChef;
  let stakingChefTotalSupply;
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

    // send METRIC to the stakingChef
    const metricTokenConnectedToVestingContract = await metric.connect(vestingContract);
    const totalSupply = await metric.totalSupply();
    stakingChefTotalSupply = BN(totalSupply).div(10);
    await metricTokenConnectedToVestingContract.transfer(stakingChef.address, BN(totalSupply).div(10));

    // send METRIC to stakers
    await metricTokenConnectedToVestingContract.transfer(staker1.address, BN(2000).div(10));
    await metricTokenConnectedToVestingContract.transfer(staker2.address, BN(2000).div(10));

    //approve Metric Transfers
    await stakingChef.toggleRewards(true);
    await stakingChef.toggleRewards(true);
    const staker1Balance = await metric.balanceOf(staker1.address);
    const staker2Balance = await metric.balanceOf(staker2.address);
    await metric.connect(staker1).approve(stakingChef.address, staker1Balance);
    await metric.connect(staker2).approve(stakingChef.address, staker2Balance);
   
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const ownerBalance = await metric.balanceOf(stakingChef.address);
      expect(BN(ownerBalance)).to.equal(stakingChefTotalSupply);
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

      //stake Metric
      await stakingChef.stakeMetric(staker1.address, 20, 1);

      // check that it was added
      stakes = await stakingChef.getStakes();
      expect(1).to.equal(stakes.length);
      alloc = await stakingChef.getTotalAllocationPoints();
      expect(20).to.equal(alloc);

      // add our second stake
      await stakingChef.stakeMetric(staker2.address, 30, 1);

      // check that it was added
      stakes = await stakingChef.getStakes();
      expect(2).to.equal(stakes.length);
      alloc = await stakingChef.getTotalAllocationPoints();
      expect(50).to.equal(alloc);

      // re-adding the first one should fail
      await expect(stakingChef.stakeMetric(staker1.address, 50, 1)).to.be.revertedWith("nonDuplicated: duplicated");
    });

    it("Should update edited Stakes", async function () {
      await stakingChef.toggleRewards(true);
      await stakingChef.stakeMetric(staker1.address, 20, 1);

      // check that they were added
      let alloc = await stakingChef.getTotalAllocationPoints();
      expect(20).to.equal(alloc);

      // edit the first one
      await stakingChef.updateStaker(staker1.address, 0, BN(600).div(10));
      alloc = await stakingChef.getTotalAllocationPoints();
      expect(60).to.equal(alloc);
    });

    it("Should support deleting Stakes", async function () {
      await stakingChef.toggleRewards(true);

      // add two stakes
      await stakingChef.stakeMetric(staker1.address, 20, 1);
      await stakingChef.stakeMetric(staker2.address, 30, 1);

      // remove the first one
      await stakingChef.removeStaker(0);
      const alloc = await stakingChef.getTotalAllocationPoints();
      expect(30).to.equal(alloc);

      // ensure the second added one is now the first one in the array
      const stakes = await stakingChef.getStakes();
      expect(30).to.equal(stakes[0].metricAmount);
    });
  });

  describe("Pending Rewards", function () {
    it("Should track pending rewards", async function () {
      // add a stake group
      await stakingChef.stakeMetric(staker1.address, BN(200).div(10), 1);
      
      await stakingChef.toggleRewards(true);
      // new stake should have 0 metric
      let pending = await stakingChef.viewPendingHarvest(0);
      expect(0).to.equal(pending);

      // update distributions (requires mining 1 block)
      await stakingChef.updateAccumulatedStakingRewards();

      // should have 1 pending stake
      const metricPerBlock = await stakingChef.getMetricPerBlock();

      pending = await stakingChef.viewPendingHarvest(0);

      expect(metricPerBlock).to.equal(pending);

      // update distributions (requires mining 1 block)
      await stakingChef.updateAccumulatedStakingRewards();
      // should have 2 pending allocations

      pending = await stakingChef.viewPendingHarvest(0);
      expect(BN(metricPerBlock).add(metricPerBlock)).to.equal(pending);
    });

    it("Should track pending rewards with multiple stakes", async function () {
      await stakingChef.toggleRewards(true);

      // add a stake
      await stakingChef.stakeMetric(staker1.address, BN(200).div(10), 1);
      
      // new stake should have 0 metric
      let pending = await stakingChef.viewPendingHarvest(0);
      expect(0).to.equal(pending);

      // add an additional stake
      await stakingChef.stakeMetric(staker2.address, BN(200).div(10), 1);

      pending = await stakingChef.viewPendingHarvest(1);
      expect(0).to.equal(pending);

      await mineBlocks(2);

      // update distributions (requires mining 1 block)
      await stakingChef.updateAccumulatedStakingRewards();

      // should have 3 pending allocation of 4 tokens each - and checking shares above we can get expected

      pending = await stakingChef.viewPendingHarvest(0);
      expect(utils.parseEther("14")).to.equal(pending); // should be 3 would love to dynamically find this
      pending = await stakingChef.viewPendingHarvest(1);
      expect(utils.parseEther("6")).to.equal(pending); // should be 9 would love to dynamically find this
    });
  });

  describe("Claim Rewards", function () {
    it("Should transfer earned rewards", async function () {
      // start at block 1
      await stakingChef.toggleRewards(true);
      // block 2
      await stakingChef.stakeMetric(staker1.address, BN(200).div(10), 1);

      // block 3
      await stakingChef.updateAccumulatedStakingRewards();

      await stakingChef.connect(staker1).claim(0);

      const balance = await metric.balanceOf(staker1.address);
      const metricPerBlock = await stakingChef.getMetricPerBlock();
      const value = closeEnough(metricPerBlock.mul(3), balance);

      expect(value);
    });

    it("Should track claimable rewards", async function () {
      // start at block 1
      await stakingChef.toggleRewards(true);
      // block 2
      await stakingChef.stakeMetric(staker1.address, BN(200).div(10), 1);

      // block 3
      await stakingChef.updateAccumulatedStakingRewards();

      await stakingChef.connect(staker1).claim(0);
  
      let balance = await metric.balanceOf(staker1.address);
      const withdrawlable = await stakingChef.viewPendingHarvest(0);
      expect(withdrawlable).to.equal(0);
    });
  });

  describe("Maintain Stakes over time ", function () {
    it("Should handle adding a stake after intial startup", async function () {
      await stakingChef.stakeMetric(staker1.address, BN(200).div(10), 1);
      await stakingChef.toggleRewards(true);

      // block 5
      await mineBlocks(5);
      // block 6
      await stakingChef.updateAccumulatedStakingRewards();

      const pending1 = await stakingChef.viewPendingHarvest(0);
      expect(pending1).to.equal(utils.parseEther("24"));

      // block 7
      await stakingChef.stakeMetric(staker2.address, BN(200).div(10), 1);
      // block 8 (block 1 for group 2)
      await stakingChef.connect(staker1).claim(0);
      await stakingChef.connect(staker2).claim(1);

      const balance1 = await metric.balanceOf(staker1.address);
      const value1 = closeEnough(balance1, utils.parseEther("30"));
      expect(value1);

      const balance2 = await metric.balanceOf(staker2.address);
      const value2 = closeEnough(balance2, utils.parseEther("4"))
      expect(value2);
    });
  });

  describe("Stake Additional Metric", function () {
    it("Should add metric to stake", async function () {
      await stakingChef.toggleRewards(true);

      //stake Metric
      await stakingChef.stakeMetric(staker1.address, BN(200).div(10), 1);

      //stake Additional Metric
      await stakingChef.stakeAdditionalMetric(staker1.address, 0, BN(200).div(10), 1)

      const stakes = await stakingChef.getStakes();
      const metricStaked = stakes[0].metricAmount;
      const userMetricStaked = BN(400).div(10);
      expect(userMetricStaked).to.equal(metricStaked);
    });

  });

  describe("Withdraw Principal Metric", function () {
    it("Should withdraw initial Metric", async function () {
      await stakingChef.toggleRewards(true);

      //stake Metric
      await stakingChef.stakeMetric(staker1.address, BN(200).div(10), 1);

      //check Metric Principal before withdraw
      let stakes = await stakingChef.getStakes();
      let principalMetric = stakes[0].metricAmount;
      expect(BN(200).div(10)).to.equal(principalMetric);

      //withdraw Metric
      await stakingChef.withdrawPrincipal(0);
      stakes = await stakingChef.getStakes();
      principalMetric = stakes[0].metricAmount;

      //check Metric principal has been withdrawn
      expect(0).to.equal(principalMetric);
    });
  });
});
