const { expect } = require("chai");
const { utils } = require("ethers");
const { ethers, network } = require("hardhat");
const { mineBlocks, BN, closeEnough } = require("./utils");

describe("Staking Contract", function () {
  let stakingChef;
  let stakingChefTotalSupply;
  let metric;

  let origin;
  let staker1;
  let staker2;
  let vestingContract;

  beforeEach(async function () {
    // Set To TRUE as tests are based on hardhat.config
    await network.provider.send("evm_setAutomine", [true]);

    [origin, staker1, staker2, vestingContract] = await ethers.getSigners();

    // deploy METRIC
    const metricContract = await ethers.getContractFactory("MetricToken");
    metric = await metricContract.deploy();

    // deploy StakingChef, which requires a reference to METRIC
    const stakingChefContract = await ethers.getContractFactory("StakingChef");
    stakingChef = await stakingChefContract.deploy(metric.address);

    // send METRIC to the stakingChef
    const totalSupply = await metric.totalSupply();
    stakingChefTotalSupply = BN(totalSupply).div(10);
    await metric.transfer(stakingChef.address, BN(totalSupply).div(10));

    // send METRIC to stakers
    await metric.transfer(staker1.address, BN(2000).div(10));
    await metric.transfer(staker2.address, BN(2000).div(10));

    // approve Metric Transfers
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
      let alloc = await stakingChef.getTotalAllocationShares();
      expect(0).to.equal(alloc);

      // stake Metric
      await stakingChef.connect(staker1).stakeMetric(BN(200).div(10));

      // check that it was added
      alloc = await stakingChef.connect(staker1).getTotalAllocationShares();
      expect(20).to.equal(alloc);

      // add our second stake
      await stakingChef.connect(staker2).stakeMetric(BN(200).div(10));

      // check that it was added
      alloc = await stakingChef.connect(staker2).getTotalAllocationShares();
      expect(40).to.equal(alloc);
    });
  });

  describe("Pending Rewards", function () {
    it("Should track pending rewards", async function () {
      // add a stake group
      await stakingChef.connect(staker1).stakeMetric(BN(200).div(10));
      await stakingChef.toggleRewards(true);
      // new stake should have 0 metric
      let pending = await stakingChef.viewPendingHarvest();
      expect(0).to.equal(pending);

      // update distributions (requires mining 1 block)
      await stakingChef.updateAccumulatedStakingRewards();

      // should have 1 pending stake
      const metricPerBlock = await stakingChef.getMetricPerBlock();

      pending = await stakingChef.connect(staker1).viewPendingHarvest();

      expect(metricPerBlock).to.equal(pending);

      // update distributions (requires mining 1 block)
      await stakingChef.updateAccumulatedStakingRewards();
      // should have 2 pending allocations

      pending = await stakingChef.connect(staker1).viewPendingHarvest();
      expect(BN(metricPerBlock).add(metricPerBlock)).to.equal(pending);
    });

    it("Should track pending rewards with multiple stakes", async function () {
      await stakingChef.toggleRewards(true);

      // add a stake
      await stakingChef.connect(staker1).stakeMetric(BN(200).div(10));
      // new stake should have 0 metric
      let pending = await stakingChef.connect(staker1).viewPendingHarvest();
      expect(0).to.equal(pending);

      // add an additional stake
      await stakingChef.connect(staker2).stakeMetric(BN(200).div(10));

      pending = await stakingChef.connect(staker2).viewPendingHarvest();
      expect(0).to.equal(pending);

      await mineBlocks(2);

      // update distributions (requires mining 1 block)
      await stakingChef.updateAccumulatedStakingRewards();

      // should have 3 pending allocation of 4 tokens each - and checking shares above we can get expected

      pending = await stakingChef.connect(staker1).viewPendingHarvest();
      expect(utils.parseEther("14")).to.equal(pending); // should be 3 would love to dynamically find this
      pending = await stakingChef.connect(staker2).viewPendingHarvest();
      expect(utils.parseEther("6")).to.equal(pending); // should be 9 would love to dynamically find this
    });
  });

  describe("Claim Rewards", function () {
    it("Should transfer earned rewards", async function () {
      // start at block 1
      await stakingChef.toggleRewards(true);
      // block 2
      await stakingChef.connect(staker1).stakeMetric(BN(200).div(10));

      // block 3
      await stakingChef.updateAccumulatedStakingRewards();

      await stakingChef.connect(staker1).claim();

      const balance = await metric.balanceOf(staker1.address);
      const metricPerBlock = await stakingChef.getMetricPerBlock();
      const value = closeEnough(metricPerBlock.mul(3), balance);

      expect(value);
    });

    it("Should track claimable rewards", async function () {
      // start at block 1
      await stakingChef.toggleRewards(true);
      // block 2
      await stakingChef.connect(staker1).stakeMetric(BN(200).div(10));

      // block 3
      await stakingChef.updateAccumulatedStakingRewards();

      await stakingChef.connect(staker1).claim();
      const withdrawlable = await stakingChef.viewPendingHarvest();
      expect(withdrawlable).to.equal(0);
    });
  });

  describe("Maintain Stakes over time ", function () {
    it("Should handle adding a stake after intial startup", async function () {
      await stakingChef.connect(staker1).stakeMetric(BN(200).div(10));
      await stakingChef.toggleRewards(true);

      // block 5
      await mineBlocks(5);
      // block 6
      await stakingChef.updateAccumulatedStakingRewards();

      const pending1 = await stakingChef.connect(staker1).viewPendingHarvest();
      expect(pending1).to.equal(utils.parseEther("24"));

      // block 7
      await stakingChef.connect(staker2).stakeMetric(BN(200).div(10));
      // block 8 (block 1 for group 2)
      await stakingChef.connect(staker1).claim();
      await stakingChef.connect(staker2).claim();

      const balance1 = await metric.balanceOf(staker1.address);
      const value1 = closeEnough(balance1, utils.parseEther("30"));
      expect(value1);

      const balance2 = await metric.balanceOf(staker2.address);
      const value2 = closeEnough(balance2, utils.parseEther("4"));
      expect(value2);
    });
  });

  describe("Stake Additional Metric", function () {
    it("Should add metric to stake", async function () {
      await stakingChef.toggleRewards(true);

      // stake Metric
      await stakingChef.connect(staker1).stakeMetric(BN(200).div(10));
      // stake Additional Metric
      await stakingChef.connect(staker1).stakeMetric(BN(200).div(10));

      const metricStaked = await stakingChef.staker(staker1.address);
      const userMetricStaked = BN(400).div(10);
      expect(userMetricStaked).to.equal(metricStaked[0]);
    });
  });

  describe("Unstake Metric", function () {
    it("Should withdraw initial Metric", async function () {
      await stakingChef.toggleRewards(true);

      // stake Metric
      await stakingChef.connect(staker1).stakeMetric(BN(200).div(10));

      // check Metric Principal before withdraw
      let principalMetric = await stakingChef.staker(staker1.address);
      expect(BN(200).div(10)).to.equal(principalMetric[0]);

      // withdraw Metric
      await stakingChef.connect(staker1).unStakeMetric();
      principalMetric = await stakingChef.staker(staker1.address);
      // check Metric principal has been withdrawn
      expect(0).to.equal(principalMetric[0]);
    });
  });
});
