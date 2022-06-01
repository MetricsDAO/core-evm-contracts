//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Chef.sol";

contract StakingChef is Chef {
    using SafeMath for uint256;
    Staker[] private _stakes;

    //mapping(address => mapping(address => userStakes)) public userStakes;

    constructor(address metricTokenAddress) {
        setMetricToken(metricTokenAddress);
        setMetricPerBlock(4);
        toggleRewards(false);
    }
// --------------------------------------------------------------------- staking functions
    function stakeMetric(
        address newAddress,
        uint256 metricAmount,
        uint256 newStartDate
    ) external nonDuplicated(newAddress) {
    if (areRewardsActive() && getTotalAllocationShares() > 0) {
            updateAccumulatedStakingRewards();
        }
        Staker memory stake = Staker({
            stakeAddress: newAddress,
            metricAmount: metricAmount, 
            startDate: newStartDate,
            rewardDebt: metricAmount.mul(getLifetimeShareValue()).div(ACC_METRIC_PRECISION),
            claimable: 0
        });

        _stakes.push(stake);
        addTotalAllocShares(stake.metricAmount);
        SafeERC20.safeTransferFrom(IERC20(getMetricToken()), msg.sender, address(this), stake.metricAmount); 
    }

    function updateStaker(
        address stakeAddress,
        uint256 stakeIndex,
        uint256 metricAmount 
    ) public {
        if (areRewardsActive() && getTotalAllocationShares() > 0) {
            updateAccumulatedStakingRewards();
        }
        addTotalAllocShares(_stakes[stakeIndex].metricAmount, metricAmount);
        _stakes[stakeIndex].stakeAddress = stakeAddress;
        _stakes[stakeIndex].metricAmount = metricAmount;
    }

    function removeStaker(uint256 stakeIndex) external {
        require(stakeIndex < _stakes.length, "Index more than stakes length");
        if (areRewardsActive() && getTotalAllocationShares() > 0) {
            updateAccumulatedStakingRewards();
        }
        removeAllocShares(_stakes[stakeIndex].metricAmount);

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
            rewardDebt: metricAmount.mul(getLifetimeShareValue()).div(ACC_METRIC_PRECISION),
            claimable: 0
            });

            _stakes[stakeIndex] = stake;
            addTotalAllocShares(stake.metricAmount);
            SafeERC20.safeTransferFrom(IERC20(getMetricToken()), msg.sender, address(this), stake.metricAmount);
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

    function claim(uint256 stakeIndex) public {
        Staker storage stake = _stakes[stakeIndex];
        harvest(stakeIndex);

        require(stake.claimable != 0, "No claimable rewards to withdraw");
        require(stake.stakeAddress == _msgSender(), "Sender can not claim");

        SafeERC20.safeTransfer(IERC20(getMetricToken()), msg.sender, stake.claimable);
        stake.claimable = 0;

        emit Withdraw(msg.sender, stakeIndex, stake.claimable);
    }

    function withdrawPrincipal(uint256 stakeIndex) public {
        Staker storage stake = _stakes[stakeIndex];

        require(stake.metricAmount != 0, "No Metric to withdraw");
        require(stake.stakeAddress == _msgSender(), "Sender can not withdraw");

        SafeERC20.safeTransfer(IERC20(getMetricToken()), msg.sender, stake.metricAmount);
        stake.metricAmount = 0;

        emit Withdraw(msg.sender, stakeIndex, stake.metricAmount);
    }

    function harvest(uint256 stakeIndex) internal {
        Staker storage stake = _stakes[stakeIndex];

        updateAccumulatedStakingRewards();

        uint256 claimable = stake.metricAmount.mul(getLifetimeShareValue()).div(ACC_METRIC_PRECISION).sub(stake.rewardDebt);

        stake.rewardDebt = claimable;
        stake.claimable = stake.claimable.add(claimable);
        emit Harvest(msg.sender, stakeIndex, claimable);
    }

//------------------------------------------------------Getters

    function getStakes() public view returns (Staker[] memory) {
        return _stakes;
    }

//------------------------------------------------------Distribution

    function viewPendingHarvest(uint256 stakeIndex) public view returns (uint256) {
        Staker storage stake = _stakes[stakeIndex];

        return stake.metricAmount.mul(getLifetimeShareValue()).div(ACC_METRIC_PRECISION).sub(stake.rewardDebt);
    }

    function viewPendingClaims(uint256 stakeIndex) public view returns (uint256) {
        Staker storage stake = _stakes[stakeIndex];

        return stake.claimable;
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

