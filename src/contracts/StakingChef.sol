//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Chef.sol";

//TODO StakeMetric, updateStaker, removeStaker, updateAccumulatedStakingRewards, harvest and Claim can be moved to Chef

contract StakingChef is Chef {
    using SafeMath for uint256;
    Staker[] private _stakes;
    uint256 private _totalAllocPoint;
    uint256 private _lifetimeShareValue;
    MetricToken public metric;


    constructor(address metricTokenAddress) {
        metric = setMetricToken(metricTokenAddress);
        setMetricPerBlock(4);
        toggleRewards(false);

    }

// --------------------------------------------------------------------- staking functions
    function stakeMetric(
        address newAddress,
        uint256 metricAmount,
        uint256 newStartDate
    ) external nonDuplicated(newAddress) {
    if (areRewardsActive() && _totalAllocPoint > 0) {
            updateAccumulatedStakingRewards();
        }
        Staker memory stake = Staker({
            stakeAddress: newAddress,
            metricAmount: metricAmount, 
            startDate: newStartDate,
            rewardDebt: metricAmount.mul(_lifetimeShareValue).div(ACC_METRIC_PRECISION),
            claimable: 0
        });

        _stakes.push(stake);
        _totalAllocPoint = _totalAllocPoint.add(stake.metricAmount);
        SafeERC20.safeTransferFrom(IERC20(metric), msg.sender, address(this), stake.metricAmount); 
    }

    function updateStaker(
        address stakeAddress,
        uint256 stakeIndex,
        uint256 metricAmount 
    ) public {
        if (areRewardsActive() && _totalAllocPoint > 0) {
            updateAccumulatedStakingRewards();
        }
        _totalAllocPoint = _totalAllocPoint.sub(_stakes[stakeIndex].metricAmount).add(metricAmount);
        _stakes[stakeIndex].stakeAddress = stakeAddress;
        _stakes[stakeIndex].metricAmount = metricAmount;
    }

    function removeStaker(uint256 stakeIndex) external {
        require(stakeIndex < _stakes.length);
        if (areRewardsActive() && _totalAllocPoint > 0) {
            updateAccumulatedStakingRewards();
        }
        _totalAllocPoint = _totalAllocPoint.sub(_stakes[stakeIndex].metricAmount);

        _stakes[stakeIndex] = _stakes[_stakes.length - 1];
        _stakes.pop();
    }

    function stakeAdditionalMetric(
        address stakeAddress,
        uint256 stakeIndex,
        uint256 metricAmount,
        uint256 newStartDate
    ) public {
        harvest(stakeIndex);
        uint256 principalMetric = _stakes[stakeIndex].metricAmount;
        uint256 totalMetricStaked = metricAmount + principalMetric;

        Staker memory stake = Staker({
            stakeAddress: stakeAddress,
            metricAmount: totalMetricStaked,
            startDate: newStartDate,
            rewardDebt: metricAmount.mul(_lifetimeShareValue).div(ACC_METRIC_PRECISION),
            claimable: 0
            });

            _stakes.push(stake);
            _totalAllocPoint = _totalAllocPoint.add(stake.metricAmount);
             SafeERC20.safeTransferFrom(IERC20(metric), msg.sender, address(this), stake.metricAmount);
    }

    function updateAccumulatedStakingRewards() public {
        require(areRewardsActive(), "Rewards are not active");
        if (block.number <= getLastRewardBlock()) {
            return;
        }

        uint256 blocks = block.number.sub(getLastRewardBlock());

        uint256 accumulated = blocks.mul(getMetricPerBlock());

        _lifetimeShareValue = _lifetimeShareValue.add(accumulated.mul(ACC_METRIC_PRECISION).div(_totalAllocPoint));
        setLastRewardBlock(block.number);
    }

// --------------------------------------------------------------------- Manage rewards and Principal

    function claim(uint256 stakeIndex) public {
        Staker storage stake = _stakes[stakeIndex];

        require(stake.claimable != 0, "No claimable rewards to withdraw");
        require(stake.stakeAddress == _msgSender(), "Sender can not claim");

        SafeERC20.safeTransferFrom(IERC20(metric), address(this), msg.sender, stake.claimable);
        stake.claimable = 0;

        emit Withdraw(msg.sender, stakeIndex, stake.claimable);
    }

    function withdrawPrincipal(uint256 stakeIndex) public {
        Staker storage stake = _stakes[stakeIndex];

        require(stake.metricAmount != 0, "No Metric to withdraw");
        require(stake.stakeAddress == _msgSender(), "Sender can not withdraw");

         SafeERC20.safeTransferFrom(IERC20(metric), address(this), msg.sender, stake.metricAmount);
        stake.metricAmount = 0;

        emit Withdraw(msg.sender, stakeIndex, stake.metricAmount);
    }

    function harvest(uint256 stakeIndex) public {
        Staker storage stake = _stakes[stakeIndex];

        updateAccumulatedStakingRewards();

        uint256 claimable = stake.metricAmount.mul(_lifetimeShareValue).div(ACC_METRIC_PRECISION).sub(stake.rewardDebt);

        stake.rewardDebt = claimable;
        stake.claimable = stake.claimable.add(claimable);
        emit Harvest(msg.sender, stakeIndex, claimable);
    }

// --------------------------------------------------------------------- Structs
    struct Staker {
        address stakeAddress;
        uint256 metricAmount;
        uint256 rewardDebt;
        uint256 claimable;
        uint256 startDate;
    }
}


