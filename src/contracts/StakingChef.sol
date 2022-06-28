//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Chef.sol";

contract StakingChef is Chef {
    mapping(address => Staker) public staker;

    constructor(address metricTokenAddress) {
        setMetricToken(metricTokenAddress);
        setMetricPerBlock(4);
        toggleRewards(false);
    }

    // --------------------------------------------------------------------- staking functions
    function stakeMetric(uint256 metricAmount) external {
        // Effects
        Staker storage stake = staker[msg.sender];

        if (areRewardsActive() && getTotalAllocationShares() > 0) {
            updateAccumulatedStakingRewards();
        }
        staker[msg.sender] = Staker({
            shares: stake.shares + metricAmount,
            startDate: block.timestamp,
            // TODO metricAmount or (stake.shares + metricAmount) // rewardDebt + metricAmount
            rewardDebt: stake.rewardDebt + (((metricAmount) * getLifetimeShareValue()) / ACC_METRIC_PRECISION),
            // TODO stake.claimable
            claimable: stake.claimable
        });

        addTotalAllocShares(metricAmount);

        // Interactions
        SafeERC20.safeTransferFrom(IERC20(getMetricToken()), msg.sender, address(this), metricAmount);
    }

    function updateAccumulatedStakingRewards() public {
        if (!areRewardsActive()) revert RewardsAreNotActive();
        if (block.number <= getLastRewardBlock()) {
            return;
        }

        setLifetimeShareValue();
        setLastRewardBlock(block.number);
    }

    // --------------------------------------------------------------------- Manage rewards and Principal

    function claim() public {
        // Checks
        if (viewPendingHarvest() == 0) revert NoClaimableRewardsToWithdraw();

        // Effects
        Staker storage stake = staker[msg.sender];
        harvest();

        uint256 toClaim = stake.claimable;
        stake.claimable = 0;

        // Interactions
        SafeERC20.safeTransfer(IERC20(getMetricToken()), msg.sender, toClaim);

        emit Claim(msg.sender, stake, toClaim);
    }

    function unStakeMetric() public {
        // Checks
        Staker storage stake = staker[msg.sender];
        if (stake.shares == 0) revert NoMetricToWithdraw();

        if (areRewardsActive()) {
            updateAccumulatedStakingRewards();
        }

        // Effects
        uint256 toWithdraw = stake.shares;
        removeAllocShares(staker[msg.sender].shares);
        stake.shares = 0;

        // Interactions
        SafeERC20.safeTransfer(IERC20(getMetricToken()), msg.sender, toWithdraw);

        emit UnStake(msg.sender, stake, toWithdraw);
    }

    function harvest() internal {
        Staker storage stake = staker[msg.sender];
        updateAccumulatedStakingRewards();

        uint256 claimable = (stake.shares * getLifetimeShareValue()) / ACC_METRIC_PRECISION - stake.rewardDebt;

        stake.rewardDebt = stake.rewardDebt + claimable;
        stake.claimable = stake.claimable + claimable;
        emit Claim(msg.sender, stake, claimable);
    }

    //------------------------------------------------------Getters

    function getStake() public view returns (Staker memory) {
        Staker storage stake = staker[msg.sender];
        return stake;
    }

    //------------------------------------------------------Distribution

    function viewPendingHarvest() public view returns (uint256) {
        Staker storage stake = staker[msg.sender];

        return (stake.shares * getLifetimeShareValue()) / ACC_METRIC_PRECISION - stake.rewardDebt;
    }

    function viewPendingClaims() public view returns (uint256) {
        Staker storage stake = staker[msg.sender];

        return stake.claimable;
    }

    // --------------------------------------------------------------------- Structs
    struct Staker {
        uint256 shares;
        uint256 rewardDebt;
        uint256 claimable;
        uint256 startDate;
    }

    // --------------------------------------------------------------------- Errors
    error RewardsAreNotActive();
    error NoMetricToWithdraw();
    error NoClaimableRewardsToWithdraw();

    // --------------------------------------------------------------------- Events
    event Claim(address harvester, StakingChef.Staker, uint256 amount);
    event UnStake(address withdrawer, StakingChef.Staker, uint256 amount);
}
