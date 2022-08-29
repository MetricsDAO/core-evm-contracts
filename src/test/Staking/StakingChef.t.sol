pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../../contracts/StakingChef.sol";
import "../../contracts/MetricToken.sol";

/// @notice Translation of https://github.com/MetricsDAO/core-evm-contracts/blob/main/test/stakingChef-test.js to foundry
contract StakingChefTest is Test {
    // Accounts
    address owner = address(0x152314518);
    address alice = address(0xa);
    address bob = address(0xb);

    MetricToken metricToken;
    StakingChef stakingChef;

    function setUp() public {
        // Label addresses
        vm.label(owner, "Owner");
        vm.label(bob, "Bob");
        vm.label(alice, "Alice");

        // Deploy METRIC & StakingChef
        vm.startPrank(owner);
        metricToken = new MetricToken();
        stakingChef = new StakingChef(address(metricToken));

        vm.label(address(metricToken), "METRIC");
        vm.label(address(stakingChef), "StakingChef");

        vm.stopPrank();

        // Distribute METRIC to users and StakingChef
        vm.startPrank(owner);
        metricToken.transfer(bob, 1000e18);
        metricToken.transfer(alice, 1000e18);
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
        uint256 balanceOwner = metricToken.balanceOf(owner);

        assertEq(balanceChef, totalSupply / 10);
        assertEq(balanceBob, balanceAlice);
        assertEq(balanceBob, 1000e18);
        assertEq(balanceOwner, (totalSupply - balanceBob - balanceAlice - balanceChef));
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

    function test_ClaimRewards() public {
        console.log("Should transfer earned rewards.");

        // Stake
        vm.startPrank(bob);
        stakingChef.stakeMetric(20e18);

        // Bob balance post stake
        uint256 bobBal = metricToken.balanceOf(bob);

        // Mine blocks
        vm.roll(block.number + 2);
        stakingChef.updateAccumulatedStakingRewards();

        // Claim
        stakingChef.claim();

        metricToken.balanceOf(bob);
        assertEq(metricToken.balanceOf(bob), bobBal + 8e18);

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
    }

    function test_StakeAdditionalMetric() public {
        console.log("Should add metric to stake.");

        // Stake
        vm.startPrank(bob);
        stakingChef.stakeMetric(10e18);

        // Stake additional
        stakingChef.stakeMetric(10e18);
        (uint256 shares, , ) = stakingChef.staker(bob);

        assertEq(shares, 20e18);
        vm.stopPrank();
    }

    function test_UnstakeMetric() public {
        console.log("Should withdraw initial Metric");

        // Stake
        vm.startPrank(bob);
        stakingChef.stakeMetric(10e18);

        // Get q shares
        (uint256 sharesStake, , ) = stakingChef.staker(bob);
        assertEq(sharesStake, 10e18);

        // Unstake
        stakingChef.unStakeMetric();

        // Get q shares
        (uint256 sharesUnstake, , ) = stakingChef.staker(bob);
        assertEq(sharesUnstake, 0);
    }

    function test_UnstakeClaimMetric() public {
        console.log("Should Claim Metric when Unstaking");

        uint256 balancestart = metricToken.balanceOf(bob);

        // Stake
        vm.startPrank(bob);
        stakingChef.stakeMetric(10e18);

        // mine a block
        vm.roll(block.number + 1);

        // Unstake
        stakingChef.unStakeMetric();

        // check earned balance
        uint256 earned = metricToken.balanceOf(bob) - balancestart;
        assertEq(earned, 4e18);
    }

    function test_StakeUnstakeStake() public {
        console.log("Should be able to stake twice.");

        // Stake & Unstake
        vm.startPrank(bob);
        stakingChef.stakeMetric(10e18);
        stakingChef.unStakeMetric();
        (uint256 sharesUnstake, , ) = stakingChef.staker(bob);
        assertEq(sharesUnstake, 0);

        // Stake again
        stakingChef.stakeMetric(10e18);
        (uint256 sharesStake, , ) = stakingChef.staker(bob);
        assertEq(sharesStake, 10e18);
    }

    function test_StakeMultipleTimes() public {
        console.log("Should account for multiple deposits correctly.");
        vm.startPrank(bob);
        stakingChef.stakeMetric(10e18);
        stakingChef.stakeMetric(15e18);
        stakingChef.stakeMetric(33e18);
        (uint256 staked, , ) = stakingChef.staker(bob);
        assertEq(staked, 58e18);

        stakingChef.unStakeMetric();
        (staked, , ) = stakingChef.staker(bob);
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

    function test_SimpleRewardsSimulation() public {
        console.log("Should account properly and adequately reflect reward calculations.");

        // Starting balances
        assertEq(metricToken.balanceOf(bob), 1000e18);
        assertEq(metricToken.balanceOf(alice), 1000e18);

        // Bob stakes 100e18
        vm.prank(bob);
        stakingChef.stakeMetric(100e18);

        // +10 blocks
        vm.roll(block.number + 10);
        stakingChef.updateAccumulatedStakingRewards();

        // Bob should have a staking position of 100
        // Bob accumulated rewards should be 40 --> 0 + ((10*40) * 100/100)

        (uint256 staked, , ) = stakingChef.staker(bob);
        assertEq(staked, 100e18);
        vm.prank(bob);
        assertEq(stakingChef.viewPendingHarvest(), 40e18);

        // Alice stakes 400e18
        vm.prank(alice);
        stakingChef.stakeMetric(400e18);

        // + 5 blocks
        vm.roll(block.number + 5);
        stakingChef.updateAccumulatedStakingRewards();

        // Bob should have a staking position of 100e18
        // Alice should ave a staking position of 400e18
        // Bob accumulated rewards should be 44e18 --> 40 + ((5*4) * (100/500))
        // Alice accumulated rewards should be 16e18 --> 0 + ((5*4) * (400/500))
        (uint256 bobStaked, , ) = stakingChef.staker(bob);
        (uint256 aliceStaked, , ) = stakingChef.staker(alice);
        assertEq(bobStaked, 100e18);
        assertEq(aliceStaked, 400e18);

        vm.prank(bob);
        assertEq(stakingChef.viewPendingHarvest(), 44e18);
        vm.prank(alice);
        assertEq(stakingChef.viewPendingHarvest(), 16e18);

        // Bob harvests
        vm.prank(bob);
        stakingChef.claim();

        // + 10 blocks
        vm.roll(block.number + 10);
        stakingChef.updateAccumulatedStakingRewards();

        // Bob should have a staking position of 100e18
        // Alice should ave a staking position of 400e18
        // Bob accumulated rewards should be 8e18 --> 0 + ((10*4) * (100/500))
        // Alice accumulated rewards should be 48e18 --> 16e18 + ((10*4) * (400/500))
        (bobStaked, , ) = stakingChef.staker(bob);
        (aliceStaked, , ) = stakingChef.staker(alice);
        assertEq(bobStaked, 100e18);
        assertEq(aliceStaked, 400e18);

        vm.prank(bob);
        assertEq(stakingChef.viewPendingHarvest(), 8e18);
        vm.prank(alice);
        assertEq(stakingChef.viewPendingHarvest(), 48e18);

        // Alice harvests
        vm.prank(alice);
        stakingChef.claim();

        (bobStaked, , ) = stakingChef.staker(bob);

        vm.prank(bob);
        stakingChef.stakeMetric(300e18);

        // +5 blocks
        vm.roll(block.number + 5);
        stakingChef.updateAccumulatedStakingRewards();

        // Bob should have a staking position of 400e18
        // Alice should ave a staking position of 400e18
        // Bob accumulated rewards should be 18e18 --> 8e18 + ((5*4) * (400/800))
        // Alice accumulated rewards should be 10e18 --> 0 + ((5*4) * (400/800))
        (bobStaked, , ) = stakingChef.staker(bob);
        (aliceStaked, , ) = stakingChef.staker(alice);
        assertEq(bobStaked, 400e18);
        assertEq(aliceStaked, 400e18);

        vm.prank(bob);
        assertEq(stakingChef.viewPendingHarvest(), 18e18);
        vm.prank(alice);
        assertEq(stakingChef.viewPendingHarvest(), 10e18);

        // Both harvest
        vm.prank(bob);
        stakingChef.claim();
        vm.prank(alice);
        stakingChef.claim();

        // Bob should have a staking position of 400e18
        // Alice should ave a staking position of 400e18
        // Bob accumulated rewards should be 0e18 --> 0 + ((0*4) * (400/800))
        // Alice accumulated rewards should be 0e18 --> 0 + ((0*4) * (400/800))
        (bobStaked, , ) = stakingChef.staker(bob);
        (aliceStaked, , ) = stakingChef.staker(alice);
        assertEq(bobStaked, 400e18);
        assertEq(aliceStaked, 400e18);

        vm.prank(bob);
        assertEq(stakingChef.viewPendingHarvest(), 0);
        vm.prank(alice);
        assertEq(stakingChef.viewPendingHarvest(), 0);

        // Get lifetimeEarnings and claimable from struct for each staker
        (, uint256 bobLifetimeEarnings, uint256 bobClaimable) = stakingChef.staker(bob);
        (, uint256 aliceLifetimeEarnings, uint256 aliceClaimable) = stakingChef.staker(alice);

        assertEq(bobClaimable, 0);
        assertEq(aliceClaimable, 0);

        assertEq(bobLifetimeEarnings, 218e18);
        assertEq(aliceLifetimeEarnings, 218e18);

        // Unstake
        vm.prank(bob);
        stakingChef.unStakeMetric();
        vm.prank(alice);
        stakingChef.unStakeMetric();

        // Final balances should reflect rewards paid out
        assertEq(metricToken.balanceOf(bob), 1062e18);
        assertEq(metricToken.balanceOf(alice), 1058e18);
    }

    function test_Getters() public {
        vm.startPrank(bob);
        stakingChef.stakeMetric(10e18);
        stakingChef.getStake();
        stakingChef.viewPendingClaims();
        vm.stopPrank();
    }
}
