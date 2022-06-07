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
            userAddress: msg.sender,
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
        uint256 totalMetricStaked = SafeMath.add(metricAmount, principalMetric);

        staker[msg.sender] = Staker({
            userAddress: msg.sender,
            shares: totalMetricStaked,
            startDate: block.timestamp,
            rewardDebt: metricAmount.mul(getLifetimeShareValue()).div(ACC_METRIC_PRECISION),
            claimable: 0
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

        emit TransferPrincipal(msg.sender, stake, stake.claimable);
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

        emit TransferPrincipal(msg.sender, stake, stake.shares);
    }

    function harvest() internal {
        Staker storage stake = staker[msg.sender];
        updateAccumulatedStakingRewards();

        uint256 claimable = stake.shares.mul(getLifetimeShareValue()).div(ACC_METRIC_PRECISION).sub(stake.rewardDebt);

        stake.rewardDebt = claimable;
        stake.claimable = stake.claimable.add(claimable);
        emit HarvestRewards(msg.sender, stake, claimable);
    }

    //------------------------------------------------------Getters

    // TODO figure out how to view stakes now that the stake array has been removed
    // function getStakes() public view returns (Staker[] memory) {
    //     return _stakes;
    // }

    //------------------------------------------------------Distribution

    function viewPendingHarvest() public view returns (uint256) {
        Staker memory stake = staker[msg.sender];

        return stake.shares.mul(getLifetimeShareValue()).div(ACC_METRIC_PRECISION).sub(stake.rewardDebt);
    }

    function viewPendingClaims() public view returns (uint256) {
        Staker memory stake = staker[msg.sender];

        return stake.claimable;
    }

    // --------------------------------------------------------------------- Structs
    struct Staker {
        address userAddress;
        uint256 shares;
        uint256 rewardDebt;
        uint256 claimable;
        uint256 startDate;
    }

    // --------------------------------------------------------------------- Events
    event HarvestRewards(address harvester, StakingChef.Staker, uint256 amount);
    event TransferPrincipal(address withdrawer, StakingChef.Staker, uint256 amount);
}
