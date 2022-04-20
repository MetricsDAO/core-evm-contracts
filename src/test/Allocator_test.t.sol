// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "@contracts/Allocator.sol";
import "@contracts/MetricToken.sol";



contract TokenUser {
  MetricToken _metric;
  Allocator _allocator;
    constructor(MetricToken token_, Allocator allocator) {
        _metric = token_;
        _allocator = allocator;
    }

    function tryToggleRewards() public {
        _allocator.toggleRewards(true);
    }
}

contract ContractTest is DSTest {
    MetricToken _metric;
    address _metricTokenAddress;
    Allocator allocator;
    TokenUser userOne;

    function setUp() public {
      _metric = new MetricToken();
      _metricTokenAddress = address(_metric);
      allocator = new Allocator(_metric);
      userOne = new TokenUser(_metric, allocator);
    }

    function testDeployedToken() public {
        assertTrue(_metricTokenAddress == address(MetricToken(_metricTokenAddress)));
    }

    function testRoleAssignment() public {
        assertTrue(allocator.hasRole(keccak256("ALLOCATION_ROLE"), address(this)));
    }

    function testFailRoleAssignment() public {
        assertTrue(allocator.hasRole(keccak256("ALLOCATION_ROLE"), address(userOne)));
    }

    function testFailToggle() public {
      userOne.tryToggleRewards();
    }

    function testToggleRewards() public {
      allocator.toggleRewards(true);
    }

    function testAddAllocationGroup() public {
      assertEq(allocator._numberOfAllocationGroups(), 0);
      allocator.addAllocationGroup(address(this), 100, true);
      assertEq(allocator._numberOfAllocationGroups(), 1);
    }

    function testGetAllocationGroup() public {
      allocator.addAllocationGroup(address(this), 100, true);
      assertEq(allocator.getAllocationGroup(0).groupAddress, address(this));
      assertEq(allocator.getAllocationGroup(0).shares, 100);
      assertTrue(allocator.getAllocationGroup(0).isActive);
      assertTrue(allocator.getAllocationGroup(0).autodistribute);
      assertEq(allocator.getAllocationGroup(0).rewardDebt, 0);
    }

    function testToggleActiveForAllocationGroup() public {
      allocator.addAllocationGroup(address(this), 100, true);
      allocator.updateAllocationGroupStatus(0,false);
      assertTrue(!allocator.getAllocationGroup(0).isActive);
      allocator.updateAllocationGroupStatus(0, true);
      assertTrue(allocator.getAllocationGroup(0).isActive);
    }

    function testUpdateAGShares() public {
      allocator.addAllocationGroup(address(this), 100, true);
      allocator.updateAllocationGroupShares(0, 200);
      assertEq(allocator.getAllocationGroup(0).shares, 200);
    }

    function testFailHarvestAllBeforeRewardsToggled() public {
      allocator.addAllocationGroup(address(this), 100, true);
      allocator.harvestAll();
      assertEq(allocator.getAllocationGroup(0).rewardDebt, 100);
      // assertEq(metricToken.balanceOf(address(this)), 100);
    }

    function activateRewards() public {
      allocator.toggleRewards(true);
    }

    function testHarvestAll() public {
      allocator.addAllocationGroup(address(this), 100, true);
      activateRewards();
      allocator.harvestAll();
      assertEq(allocator.getAllocationGroup(0).rewardDebt, 0);
      assertEq(_metric.balanceOf(address(this)), 1000000000000000000000000000);
    }
}
