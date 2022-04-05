const { expect } = require("chai");
const { utils } = require("ethers");
const { ethers } = require("hardhat");
const { mineBlocks, add, BN } = require("./utils");

describe("Allocator Contract", function () {
  let allocator;
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

    // deploy Allocator, which requires a reference to METRIC
    const allocatorContract = await ethers.getContractFactory("Allocator");
    allocator = await allocatorContract.deploy(metric.address);
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      // sanity check permissions
      expect(await allocator.hasRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("DISTRIBUTOR_ROLE")), owner.address)).to.equal(true);
      expect(await allocator.hasRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("DISTRIBUTOR_ROLE")), addr1.address)).to.equal(false);
    });
  });

  describe("Allocation Groups", function () {
    it("Should add and track added AGs", async function () {
      // Everything should start empty
      let groups = await allocator.getAllocationGroups();
      expect(0).to.equal(groups.length);
      let alloc = await allocator.getTotalAllocationPoints();
      expect(0).to.equal(alloc);

      // add our first allocation group
      await allocator.addAllocationGroup(allocationGroup1.address, 20, true);

      // check that it was added
      groups = await allocator.getAllocationGroups();
      expect(1).to.equal(groups.length);
      alloc = await allocator.getTotalAllocationPoints();
      expect(20).to.equal(alloc);

      // add our second allocation group
      await allocator.addAllocationGroup(allocationGroup2.address, 30, true);

      // check that it was added
      groups = await allocator.getAllocationGroups();
      expect(2).to.equal(groups.length);
      alloc = await allocator.getTotalAllocationPoints();
      expect(50).to.equal(alloc);

      // re-adding the first one should fail
      await expect(allocator.addAllocationGroup(allocationGroup1.address, 50, true)).to.be.revertedWith("nonDuplicated: duplicated");
    });

    it("Should update edited AGs", async function () {
      // add two allocation groups
      await allocator.addAllocationGroup(allocationGroup1.address, 20, true);
      await allocator.addAllocationGroup(allocationGroup2.address, 30, true);

      // check that they were added
      let alloc = await allocator.getTotalAllocationPoints();
      expect(50).to.equal(alloc);

      // edit the first one
      await allocator.updateAllocationGroup(0, 30, true);
      alloc = await allocator.getTotalAllocationPoints();
      expect(60).to.equal(alloc);
    });

    it("Should support deleting AGs", async function () {
      // add two allocation groups
      await allocator.addAllocationGroup(allocationGroup1.address, 20, true);
      await allocator.addAllocationGroup(allocationGroup2.address, 30, true);

      // remove the first one
      await allocator.removeAllocationGroup(0);
      const alloc = await allocator.getTotalAllocationPoints();
      expect(30).to.equal(alloc);

      // ensure the second added one is now the first one in the array
      const groups = await allocator.getAllocationGroups();
      expect(30).to.equal(groups[0].shares);
    });
  });

  describe("Distribution", function () {
    it("Should track pending rewards", async function () {
      // add an allocation group (requires mining 1 block)
      await allocator.addAllocationGroup(allocationGroup1.address, 20, false);

      // new group should have 0 metric
      let pending = await allocator.viewPendingAllocations(0);
      expect(0).to.equal(pending);

      // update distributions (requires mining 1 block)
      await allocator.updateAllocations();

      // should have 2 pending allocation
      const metricPerBlock = await allocator.METRIC_PER_BLOCK();
      pending = await allocator.viewPendingAllocations(0);
      expect(add(metricPerBlock, metricPerBlock)).to.equal(pending);

      // update distributions (requires mining 1 block)
      await allocator.updateAllocations();

      // should have 3 pending allocations
      pending = await allocator.viewPendingAllocations(0);
      expect(BN(metricPerBlock).add(BN(metricPerBlock)).add(metricPerBlock)).to.equal(pending);
    });

    it("Should track pending rewards with multiple groups", async function () {
      // add an allocation group (requires mining 1 block)
      await allocator.addAllocationGroup(allocationGroup1.address, 1, false);

      // add an allocation group (requires mining 1 block)
      await allocator.addAllocationGroup(allocationGroup2.address, 3, false);

      // new groups should have 0 metric
      let pending = await allocator.viewPendingAllocations(0);
      expect(0).to.equal(pending);
      pending = await allocator.viewPendingAllocations(1);
      expect(0).to.equal(pending);

      // update distributions (requires mining 1 block)
      await allocator.updateAllocations();

      // should have 3 pending allocation of 4 tokens each - and checking shares above we can get expected

      pending = await allocator.viewPendingAllocations(0);
      expect(utils.parseEther("3")).to.equal(pending); // should be 3 would love to dynamically find this
      pending = await allocator.viewPendingAllocations(1);
      expect(utils.parseEther("9")).to.equal(pending); // should be 9 would love to dynamically find this
    });
  });
});
