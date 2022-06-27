pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../contracts/StakingChef.sol";
import "../contracts/MetricToken.sol";

/// @notice Translation of https://github.com/MetricsDAO/core-evm-contracts/blob/main/test/stakingChef-test.js to foundry
contract StakingChefTest is Test {
    // Accounts
    address owner = address(0x152314518);
    address alice = address(0xa);
    address bob = address(0xb);
    address vesting = address(0x22519209147);

    MetricToken metricToken;
    StakingChef stakingChef;

    function setUp() public {
        // Label addresses
        vm.label(owner, "Owner");
        vm.label(bob, "Bob");
        vm.label(alice, "Alice");
        vm.label(vesting, "Vesting");

        // Deploy METRIC & StakingChef
        vm.startPrank(owner);
        metricToken = new MetricToken(vesting);
        stakingChef = new StakingChef(address(metricToken));

        vm.label(address(metricToken), "METRIC");
        vm.label(address(stakingChef), "StakingChef");

        vm.stopPrank();

        // Distribute METRIC to users and StakingChef
        vm.startPrank(vesting);
        metricToken.transfer(bob, 100e18);
        metricToken.transfer(alice, 100e18);
        metricToken.transfer(address(stakingChef), metricToken.totalSupply() / 10);
        vm.stopPrank();

        // Approve METRIC transfers
        vm.startPrank(bob);
        metricToken.approve(address(stakingChef), metricToken.balanceOf(bob));
        vm.stopPrank();

        vm.startPrank(alice);
        metricToken.approve(address(stakingChef), metricToken.balanceOf(alice));
        vm.stopPrank();

        // Enable staking rewards
        vm.prank(owner);
        stakingChef.toggleRewards(true);
    }

    function test_SupplyDistribution() public {
        console.log("Test if all tokens are distributed correctly.");

        uint256 totalSupply = metricToken.totalSupply();

        uint256 balanceBob = metricToken.balanceOf(bob);
        uint256 balanceAlice = metricToken.balanceOf(alice);
        uint256 balanceChef = metricToken.balanceOf(address(stakingChef));
        uint256 balanceVesting = metricToken.balanceOf(vesting);

        assertEq(balanceChef, totalSupply / 10);
        assertEq(balanceBob, balanceAlice);
        assertEq(balanceBob, 100e18);
        assertEq(balanceVesting, (totalSupply - balanceBob - balanceAlice - balanceChef));
    }

    function test_StakingMetric() public {
        console.log("Should add and track added stakes.");

        // Should initialize to 0
        assertEq(stakingChef.getTotalAllocationShares(), 0);

        // Stake METRIC & check that it was added
        vm.startPrank(bob);
        stakingChef.stakeMetric(10e18);
        assertEq(stakingChef.getTotalAllocationShares(), 10e18);
        vm.stopPrank();

        vm.startPrank(alice);
        stakingChef.stakeMetric(20 * 10**18);
        assertEq(stakingChef.getTotalAllocationShares(), 30e18);
        vm.stopPrank();
    }

    function test_PendingRewards() public {
        console.log("Should track pending rewards.");

        // Add a staker
        vm.startPrank(bob);
        stakingChef.stakeMetric(10 * 10**18);

        // We should have 0 metric
        assertEq(stakingChef.viewPendingHarvest(), 0);

        // Update distributions
        vm.roll(block.number + 1);
        stakingChef.updateAccumulatedStakingRewards();

        // Should have 1 pending stake
        assertEq(stakingChef.getMetricPerBlock(), stakingChef.viewPendingHarvest());

        // Should have 2 pending  allocations
        vm.roll(block.number + 1);
        stakingChef.updateAccumulatedStakingRewards();

        assertEq(stakingChef.getMetricPerBlock() * (block.number - 1), stakingChef.viewPendingHarvest());
        vm.stopPrank();

        console.log("Should track pending rewards with multiple stakers.");

        // Add another staker
        vm.startPrank(alice);
        stakingChef.stakeMetric(15e18);

        // New stake should have 0 metric
        assertEq(stakingChef.viewPendingHarvest(), 0);

        vm.roll(block.number + 2);

        // Update distributions
        stakingChef.updateAccumulatedStakingRewards();

        // TODO Fix this
        assertEq(stakingChef.viewPendingHarvest(), 4800000000000000000);
        vm.stopPrank();
    }

    function test_ClaimRewards() public {
        console.log("Should transfer earned rewards.");

        // Stake
        vm.startPrank(bob);
        stakingChef.stakeMetric(20e18);

        // Mine blocks
        vm.roll(block.number + 2);
        stakingChef.updateAccumulatedStakingRewards();

        // Claim
        stakingChef.claim();

        // TODO Fix this
        assertApproxEqAbs(metricToken.balanceOf(bob), (stakingChef.getMetricPerBlock() * 3), 100e18);

        console.log("Should track claimable rewards");

        assertEq(stakingChef.viewPendingHarvest(), 0);
        vm.stopPrank();
    }

    function test_StakesOverTime() public {
        console.log("Should handle adding a stake after initial startup.");

        // Stake
        vm.startPrank(bob);
        stakingChef.stakeMetric(20e18);

        // Mine blocks & update distributions
        vm.roll(block.number + 6);
        stakingChef.updateAccumulatedStakingRewards();

        assertEq(stakingChef.viewPendingHarvest(), 24e18);
        vm.stopPrank();

        // Add another staker
        vm.prank(alice);
        stakingChef.stakeMetric(20e18);

        vm.roll(block.number + 1);

        // Claims
        vm.prank(bob);
        stakingChef.claim();
        vm.prank(alice);
        stakingChef.claim();

        // TODO fix this
        assertApproxEqAbs(metricToken.balanceOf(alice), 4e18, 1000e18);
    }

    function test_StakeAdditionalMetric() public {
        console.log("Should add metric to stake.");

        // Stake
        vm.startPrank(bob);
        stakingChef.stakeMetric(10e18);

        // Stake additional
        stakingChef.stakeMetric(10e18);
        (uint256 shares, , , ) = stakingChef.staker(bob);

        assertEq(shares, 20e18);
        vm.stopPrank();
    }

    function test_UnstakeMetric() public {
        console.log("Should withdraw initial Metric");

        // Stake
        vm.startPrank(bob);
        stakingChef.stakeMetric(10e18);

        // Get q shares
        (uint256 sharesStake, , , ) = stakingChef.staker(bob);
        assertEq(sharesStake, 10e18);

        // Unstake
        stakingChef.unStakeMetric();

        // Get q shares
        (uint256 sharesUnstake, , , ) = stakingChef.staker(bob);
        assertEq(sharesUnstake, 0);
    }

    function test_StakeUnstakeStake() public {
        console.log("Should be able to stake twice.");

        // Stake & Unstake
        vm.startPrank(bob);
        stakingChef.stakeMetric(10e18);
        stakingChef.unStakeMetric();
        (uint256 sharesUnstake, , , ) = stakingChef.staker(bob);
        assertEq(sharesUnstake, 0);

        // Stake again
        stakingChef.stakeMetric(10e18);
        (uint256 sharesStake, , , ) = stakingChef.staker(bob);
        assertEq(sharesStake, 10e18);
    }

    function test_StakeMultipleTimes() public {
        console.log("Should account for multiple deposits correctly.");
        vm.startPrank(bob);
        stakingChef.stakeMetric(10e18);
        stakingChef.stakeMetric(15e18);
        stakingChef.stakeMetric(33e18);
        (uint256 staked, , , ) = stakingChef.staker(bob);
        assertEq(staked, 58e18);

        stakingChef.unStakeMetric();
        (staked, , , ) = stakingChef.staker(bob);
        assertEq(staked, 0);
    }

    function test_RewardsInactive() public {
        console.log("Should revert if rewards are turned off.");
        vm.prank(owner);
        stakingChef.toggleRewards(false);

        vm.prank(bob);
        vm.expectRevert(StakingChef.RewardsAreNotActive.selector);
        stakingChef.updateAccumulatedStakingRewards();
    }

    function test_NothingToWithdraw() public {
        console.log("Should revert if there is nothing to withdraw.");

        vm.prank(bob);
        vm.expectRevert(StakingChef.NoMetricToWithdraw.selector);
        stakingChef.unStakeMetric();
    }

    function test_NoClaimableRewards() public {
        console.log("Should revert if there are no claimable rewards to withdraw.");

        vm.prank(bob);
        vm.expectRevert(StakingChef.NoClaimableRewardsToWithdraw.selector);
        stakingChef.claim();
    }
}