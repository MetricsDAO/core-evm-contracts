pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../contracts/TopChef.sol";
import "../contracts/MetricToken.sol";

/// @notice Translation of https://github.com/MetricsDAO/core-evm-contracts/blob/main/test/chef-test.js to foundry
contract topChefTest is Test {
    // Accounts
    address owner = address(0x152314518);
    address groupOne = address(0xa);
    address groupTwo = address(0xb);

    MetricToken metricToken;
    TopChef topChef;

    function setUp() public {
        // Label addresses
        vm.label(owner, "Owner");
        vm.label(groupOne, "gOne");
        vm.label(groupTwo, "gTwo");

        // Deploy METRIC & topChef
        vm.startPrank(owner);
        metricToken = new MetricToken();
        topChef = new TopChef(address(metricToken));

        vm.label(address(metricToken), "METRIC");
        vm.label(address(topChef), "topChef");

        vm.stopPrank();

        // Distribute METRIC to topChef
        vm.startPrank(owner);
        metricToken.transfer(address(topChef), metricToken.totalSupply());
        vm.stopPrank();

        // Enable staking rewards
        vm.prank(owner);
        topChef.toggleRewards(true);
    }

    function test_SupplyDistribution() public {
        console.log("Test if all tokens are distributed correctly.");

        uint256 totalSupply = metricToken.totalSupply();
        uint256 balanceChef = metricToken.balanceOf(address(topChef));

        assertEq(balanceChef, totalSupply);
    }

    function test_AllocationGroups() public {
        console.log("Should add and track added ags.");

        // Should initialize to 0
        assertEq(topChef.getAllocationGroups().length, 0);
        assertEq(topChef.getTotalAllocationShares(), 0);

        // Add first group
        vm.startPrank(owner);
        topChef.addAllocationGroup(groupOne, 20);

        // Check that it was added
        assertEq(topChef.getAllocationGroups().length, 1);
        assertEq(topChef.getTotalAllocationShares(), 20);

        // Add second group
        topChef.addAllocationGroup(groupTwo, 30);

        // Check that it was added
        assertEq(topChef.getAllocationGroups().length, 2);
        assertEq(topChef.getTotalAllocationShares(), 50);

        // Readding first one should fail
        vm.expectRevert(Chef.DuplicateAddress.selector);
        topChef.addAllocationGroup(groupOne, 20);

        vm.stopPrank();
    }

    function test_EditAllocationGroups() public {
        console.log("Should add and track added ags.");
        // Add first group
        vm.startPrank(owner);
        topChef.addAllocationGroup(groupOne, 20);

        // Check that it was added
        assertEq(topChef.getAllocationGroups().length, 1);
        assertEq(topChef.getTotalAllocationShares(), 20);

        // Add second group
        topChef.addAllocationGroup(groupTwo, 30);

        // Check that it was added
        assertEq(topChef.getAllocationGroups().length, 2);
        assertEq(topChef.getTotalAllocationShares(), 50);

        // Edit first one
        topChef.updateAllocationGroup(groupOne, 0, 30);

        // Check that it was updated
        assertEq(topChef.getTotalAllocationShares(), 60);

        vm.stopPrank();
    }

    function test_DeleteAllocationGroup() public {
        console.log("Should support deleting AGs.");

        vm.startPrank(owner);
        topChef.addAllocationGroup(groupOne, 20);

        // Check that it was added
        assertEq(topChef.getAllocationGroups().length, 1);
        assertEq(topChef.getTotalAllocationShares(), 20);

        // Add second group
        topChef.addAllocationGroup(groupTwo, 30);

        // Check that it was added
        assertEq(topChef.getAllocationGroups().length, 2);
        assertEq(topChef.getTotalAllocationShares(), 50);

        // Remove the first one
        topChef.removeAllocationGroup(0);
        assertEq(topChef.getTotalAllocationShares(), 30);
    }

    function test_MonitorPendingRewardsSingleGroup() public {
        console.log("Should track pending rewards.");

        // Add a group
        vm.startPrank(owner);
        topChef.addAllocationGroup(groupOne, 20);

        assertEq(topChef.viewPendingHarvest(0), 0);

        // Mine a block
        vm.roll(block.number + 1);
        topChef.updateAccumulatedAllocations();

        // Full reward should go to group at index 0
        assertEq(topChef.viewPendingHarvest(0), topChef.getMetricPerBlock());

        // Mine another block
        vm.roll(block.number + 1);
        topChef.updateAccumulatedAllocations();

        // Another full reward should be added to group at index 0
        assertEq(topChef.viewPendingHarvest(0), 2 * topChef.getMetricPerBlock());
        vm.stopPrank();
    }

    function test_MonitorPendingRewardsMultipleGroups() public {
        console.log("Should track pending rewards with multiple groups.");

        // Add two groups
        vm.startPrank(owner);
        topChef.addAllocationGroup(groupOne, 1);
        topChef.addAllocationGroup(groupTwo, 3);

        // Should initialize to 0
        assertEq(topChef.viewPendingHarvest(0), 0);
        assertEq(topChef.viewPendingHarvest(1), 0);

        // Mine 2 blocks
        vm.roll(block.number + 2);
        topChef.updateAccumulatedAllocations();

        // Confirm reward distribution || Rewards emitted: 2 blocks * metricPerBlock = 12 || gOneAlloc = 25% gTwoAlloc = 75%
        assertEq(topChef.viewPendingHarvest(0), 2e18);
        assertEq(topChef.viewPendingHarvest(1), 6e18);
    }

    function test_Harvesting() public {
        console.log("Should transfer earned rewards.");

        // Add a group
        vm.startPrank(owner);
        topChef.addAllocationGroup(groupOne, 1);

        // Mine 2 blocks
        vm.roll(block.number + 2);
        topChef.updateAccumulatedAllocations();
        vm.stopPrank();

        // Claim
        vm.prank(groupOne);
        topChef.claim(0);

        // Verify reward
        assertEq(metricToken.balanceOf(groupOne), 8e18);
    }

    function test_ClaimableRewards() public {
        console.log("Should track claimable rewards.");

        // Add a group
        vm.startPrank(owner);
        topChef.addAllocationGroup(groupOne, 1);

        // Mine 2 blocks
        vm.roll(block.number + 2);
        topChef.updateAccumulatedAllocations();
        vm.stopPrank();

        // Claim
        vm.prank(groupOne);
        topChef.harvest(0);

        assertEq(metricToken.balanceOf(groupOne), 0);
        assertEq(topChef.viewPendingClaims(0), 8e18);

        // Mine 100 blocks
        vm.roll(block.number + 100);
        topChef.updateAccumulatedAllocations();

        uint256 pReward = topChef.viewPendingRewards(0);

        vm.prank(groupOne);
        topChef.claim(0);

        assertEq(metricToken.balanceOf(groupOne), pReward);
    }

    function test_MaintainAGsOverTime() public {
        console.log("Should handle adding an AG after intial startup.");

        // Add a group
        vm.startPrank(owner);
        topChef.addAllocationGroup(groupOne, 1);

        // Mine 2 blocks
        vm.roll(block.number + 2);
        topChef.updateAccumulatedAllocations();
        vm.stopPrank();

        // Claim
        vm.prank(groupOne);
        topChef.claim(0);
        assertEq(metricToken.balanceOf(groupOne), 8e18);

        vm.prank(owner);
        topChef.addAllocationGroup(groupTwo, 1);

        // Mine 2 blocks
        vm.roll(block.number + 1);
        topChef.updateAccumulatedAllocations();

        // Claim group 2
        vm.prank(groupTwo);
        topChef.claim(1);
        assertEq(metricToken.balanceOf(groupTwo), 2e18);
    }

    function test_HarvestMultipleGroups() public {
        console.log("Should Harvest All for multiple groups.");

        vm.startPrank(owner);
        topChef.addAllocationGroup(groupOne, 1);

        // Check that it was added
        assertEq(topChef.getAllocationGroups().length, 1);
        assertEq(topChef.getTotalAllocationShares(), 1);

        // Add second group
        topChef.addAllocationGroup(groupTwo, 3);

        // Check that it was added
        assertEq(topChef.getAllocationGroups().length, 2);
        assertEq(topChef.getTotalAllocationShares(), 4);

        // Mine 2 blocks
        vm.roll(block.number + 2);
        topChef.updateAccumulatedAllocations();
        topChef.harvestAll();
        vm.stopPrank();

        vm.prank(groupOne);
        topChef.claim(0);
        vm.prank(groupTwo);
        topChef.claim(1);

        assertEq(metricToken.balanceOf(groupOne), 2e18);
        assertEq(metricToken.balanceOf(groupTwo), 6e18);
    }

    function test_InactiveRewards() public {
        vm.prank(owner);
        topChef.toggleRewards(false);

        vm.prank(owner);
        vm.expectRevert(TopChef.RewardsInactive.selector);
        topChef.harvest(0);
    }
}
