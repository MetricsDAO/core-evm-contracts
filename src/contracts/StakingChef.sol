//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Chef.sol";

contract StakingChef is Chef {
    using SafeMath for uint256;

    mapping(address => Staker) public staker;

    constructor(address metricTokenAddress) {
        setMetricToken(metricTokenAddress);
        setMetricPerBlock(4);
        toggleRewards(false);
    }

    // --------------------------------------------------------------------- staking functions
    function stakeMetric(uint256 metricAmount) external nonDuplicated(msg.sender) {
        if (areRewardsActive() && getTotalAllocationShares() > 0) {
            updateAccumulatedStakingRewards();
        }
        staker[msg.sender] = Staker({
            shares: metricAmount,
            startDate: block.timestamp,
            rewardDebt: metricAmount.mul(getLifetimeShareValue()).div(ACC_METRIC_PRECISION),
            claimable: 0
        });

        addTotalAllocShares(staker[msg.sender].shares);
        SafeERC20.safeTransferFrom(IERC20(getMetricToken()), msg.sender, address(this), staker[msg.sender].shares);
    }

    function updateStaker(uint256 metricAmount) public {
        if (areRewardsActive() && getTotalAllocationShares() > 0) {
            updateAccumulatedStakingRewards();
        }
        addTotalAllocShares(staker[msg.sender].shares, metricAmount);
        staker[msg.sender].shares = metricAmount;
    }

    function stakeAdditionalMetric(uint256 metricAmount) public {
        Staker storage stake = staker[msg.sender];
        harvest();
        uint256 principalMetric = stake.shares;
        uint256 totalMetricStaked = metricAmount.add(principalMetric);

        staker[msg.sender] = Staker({
            shares: totalMetricStaked,
            startDate: block.timestamp,
            rewardDebt: staker[msg.sender].rewardDebt,
            claimable: staker[msg.sender].claimable
        });

        addTotalAllocShares(stake.shares);
        SafeERC20.safeTransferFrom(IERC20(getMetricToken()), msg.sender, address(this), stake.shares);
    }

    function updateAccumulatedStakingRewards() public {
        require(areRewardsActive(), "Rewards are not active");
        if (block.number <= getLastRewardBlock()) {
            return;
        }

        setLifetimeShareValue();
        setLastRewardBlock(block.number);
    }

    // --------------------------------------------------------------------- Manage rewards and Principal

    function claim() public {
        Staker storage stake = staker[msg.sender];
        harvest();

        require(stake.claimable != 0, "No claimable rewards to withdraw");

        SafeERC20.safeTransfer(IERC20(getMetricToken()), msg.sender, stake.claimable);
        stake.claimable = 0;

        emit Claim(msg.sender, stake, stake.claimable);
    }

    function unStakeMetric() public {
        Staker storage stake = staker[msg.sender];
        require(stake.shares != 0, "No Metric to withdraw");

        if (areRewardsActive()) {
            updateAccumulatedStakingRewards();
        }

        removeAllocShares(staker[msg.sender].shares);

        SafeERC20.safeTransfer(IERC20(getMetricToken()), msg.sender, stake.shares);
        stake.shares = 0;

        emit UnStake(msg.sender, stake, stake.shares);
    }

    function harvest() internal {
        Staker storage stake = staker[msg.sender];
        updateAccumulatedStakingRewards();

        uint256 claimable = stake.shares.mul(getLifetimeShareValue()).div(ACC_METRIC_PRECISION).sub(stake.rewardDebt);

        stake.rewardDebt = stake.rewardDebt.add(claimable);
        stake.claimable = stake.claimable.add(claimable);
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

        return stake.shares.mul(getLifetimeShareValue()).div(ACC_METRIC_PRECISION).sub(stake.rewardDebt);
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

    // --------------------------------------------------------------------- Events
    event Claim(address harvester, StakingChef.Staker, uint256 amount);
    event UnStake(address withdrawer, StakingChef.Staker, uint256 amount);
}
