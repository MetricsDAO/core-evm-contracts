const { expect } = require("chai");
const { utils } = require("ethers");
const { ethers } = require("hardhat");
const { mineBlocks, add, BN } = require("./utils");

describe("Allocator Contract", function () {
  let chef;
  let metric;
  let owner;
  let addr1;

  let allocationGroup1;
  let allocationGroup2;
  let addrs;

  beforeEach(async function () {
    [owner, addr1, allocationGroup1, allocationGroup2, ...addrs] = await ethers.getSigners();

    // deploy METRIC
    const metricContract = await ethers.getContractFactory("MetricToken");
    metric = await metricContract.deploy();

    // deploy Chef, which requires a reference to METRIC
    const chefContract = await ethers.getContractFactory("Chef");
    chef = await chefContract.deploy(metric.address);

    // send all METRIC to the chef
    await metric.transfer(chef.address, await metric.totalSupply());
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      // sanity check permissions
      expect(await chef.hasRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("ALLOCATION_ROLE")), owner.address)).to.equal(true);
      expect(await chef.hasRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("ALLOCATION_ROLE")), addr1.address)).to.equal(false);
    });
  });

  describe("Allocation Groups", function () {
    it("Should add and track added AGs", async function () {
      await chef.toggleRewards(true);
      // Everything should start empty
      let groups = await chef.getAllocationGroups();
      expect(0).to.equal(groups.length);
      let alloc = await chef.getTotalAllocationPoints();
      expect(0).to.equal(alloc);

      // add our first allocation group
      await chef.addAllocationGroup(allocationGroup1.address, 20, true);

      // check that it was added
      groups = await chef.getAllocationGroups();
      expect(1).to.equal(groups.length);
      alloc = await chef.getTotalAllocationPoints();
      expect(20).to.equal(alloc);

      // add our second allocation group
      await chef.addAllocationGroup(allocationGroup2.address, 30, true);

      // check that it was added
      groups = await chef.getAllocationGroups();
      expect(2).to.equal(groups.length);
      alloc = await chef.getTotalAllocationPoints();
      expect(50).to.equal(alloc);

      // re-adding the first one should fail
      await expect(chef.addAllocationGroup(allocationGroup1.address, 50, true)).to.be.revertedWith("nonDuplicated: duplicated");
    });

    it("Should update edited AGs", async function () {
      await chef.toggleRewards(true);
      // add two allocation groups
      await chef.addAllocationGroup(allocationGroup1.address, 20, true);
      await chef.addAllocationGroup(allocationGroup2.address, 30, true);

      // check that they were added
      let alloc = await chef.getTotalAllocationPoints();
      expect(50).to.equal(alloc);

      // edit the first one
      await chef.updateAllocationGroup(0, 30, true);
      alloc = await chef.getTotalAllocationPoints();
      expect(60).to.equal(alloc);
    });

    it("Should support deleting AGs", async function () {
      await chef.toggleRewards(true);
      // add two allocation groups
      await chef.addAllocationGroup(allocationGroup1.address, 20, true);
      await chef.addAllocationGroup(allocationGroup2.address, 30, true);

      // remove the first one
      await chef.removeAllocationGroup(0);
      const alloc = await chef.getTotalAllocationPoints();
      expect(30).to.equal(alloc);

      // ensure the second added one is now the first one in the array
      const groups = await chef.getAllocationGroups();
      expect(30).to.equal(groups[0].shares);
    });
  });

  describe("Pending Rewards", function () {
    it("Should track pending rewards", async function () {
      await chef.toggleRewards(true);
      // add an allocation group (requires mining 1 block)
      await chef.addAllocationGroup(allocationGroup1.address, 20, false);

      // new group should have 0 metric
      let pending = await chef.viewPendingHarvest(0);
      expect(0).to.equal(pending);

      // update distributions (requires mining 1 block)
      await chef.updateAccumulatedAllocations();

      // should have 2 pending allocation
      const metricPerBlock = await chef.METRIC_PER_BLOCK();
      pending = await chef.viewPendingHarvest(0);
      expect(add(metricPerBlock, metricPerBlock)).to.equal(pending);

      // update distributions (requires mining 1 block)
      await chef.updateAccumulatedAllocations();

      // should have 3 pending allocations
      pending = await chef.viewPendingHarvest(0);
      expect(BN(metricPerBlock).add(BN(metricPerBlock)).add(metricPerBlock)).to.equal(pending);
    });

    it("Should track pending rewards with multiple groups", async function () {
      await chef.toggleRewards(true);
      // add an allocation group (requires mining 1 block)
      await chef.addAllocationGroup(allocationGroup1.address, 1, false);

      // add an allocation group (requires mining 1 block)
      await chef.addAllocationGroup(allocationGroup2.address, 3, false);

      // new groups should have 0 metric
      let pending = await chef.viewPendingHarvest(0);
      expect(0).to.equal(pending);
      pending = await chef.viewPendingHarvest(1);
      expect(0).to.equal(pending);

      // update distributions (requires mining 1 block)
      await chef.updateAccumulatedAllocations();

      // should have 3 pending allocation of 4 tokens each - and checking shares above we can get expected

      pending = await chef.viewPendingHarvest(0);
      expect(utils.parseEther("3")).to.equal(pending); // should be 3 would love to dynamically find this
      pending = await chef.viewPendingHarvest(1);
      expect(utils.parseEther("9")).to.equal(pending); // should be 9 would love to dynamically find this
    });
  });
  describe("Harvest Rewards", function () {
    it("Should transfer earned rewards", async function () {
      // start at block 1
      await chef.toggleRewards(true);
      // block 2
      await chef.addAllocationGroup(allocationGroup1.address, 1, true);

      // block 3
      await chef.updateAccumulatedAllocations();

      await chef.harvest(0);

      const balance = await metric.balanceOf(allocationGroup1.address);
      const metricPerBlock = await chef.METRIC_PER_BLOCK();

      expect(metricPerBlock.mul(3)).to.equal(balance);
    });

    it("Should track claimable rewards", async function () {
      // start at block 1
      await chef.toggleRewards(true);
      // block 2
      await chef.addAllocationGroup(allocationGroup1.address, 1, false);

      // block 3
      await chef.updateAccumulatedAllocations();

      await chef.harvest(0);

      let balance = await metric.balanceOf(allocationGroup1.address);
      const withdrawlable = await chef.viewPendingWithdraw(0);
      const metricPerBlock = await chef.METRIC_PER_BLOCK();

      expect(0).to.equal(balance);

      expect(metricPerBlock.mul(3)).to.equal(withdrawlable);

      await chef.withdraw(0);

      balance = await metric.balanceOf(allocationGroup1.address);
      expect(balance).to.equal(withdrawlable);
    });
  });
});
