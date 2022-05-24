//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Chef.sol";
import "./MetricToken.sol";

//TODO StakeMetric, updateStaker, removeStaker, updateAccumulatedStakingRewards, and Claim can be moved to Chef
//TODO Allow staker to withdrawl principal

contract StakingChef is Chef {
    using SafeMath for uint256;
    Staker[] private _stakes;
    uint256 private _totalAllocPoint;
    uint256 private _lifetimeShareValue;

    MetricToken private _metric;

    constructor(address metricTokenAddress) {
        _metric = MetricToken(metricTokenAddress);
        setMetricPerBlock(4);
    }

    mapping(address => bool) public override addressExistence;
    modifier nonDuplicated(address _address) {
        require(addressExistence[_address] == false, "nonDuplicated: duplicated");
        addressExistence[_address] = true;
        _;
    }

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
        _metric.transfer(address(this), stake.metricAmount);
        
    }

    function updateStaker(
        address stakeAddress,
        uint256 stakeIndex,
        uint256 metricAmount //is there a better name for this?
    ) public {
        if (areRewardsActive() && _totalAllocPoint > 0) {
            updateAccumulatedStakingRewards();
        }
        _totalAllocPoint = _totalAllocPoint.sub(_stakes[stakeIndex].metricAmount).add(metricAmount);
        _stakes[stakeIndex].stakeAddress = stakeAddress;
        _stakes[stakeIndex].metricAmount = metricAmount;
    }

    function removeStaker(uint256 stakeIndex, uint256 stakeAddress) external {
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
            _metric.transfer(address(this), stake.metricAmount);
    }

    function updateAccumulatedStakingRewards() public {
        require(areRewardsActive(), "Rewards are not active");
        if (block.number <= getLastRewardBlock()) {
            return;
        }

        // TODO confirm budget is correct with assertions
        // Not sure we can project emission rate over X years?
        // Not entirely sure how to handle this, but we can at least try to make it work.
        // ^^ will help with fuzz testing

        uint256 blocks = block.number.sub(getLastRewardBlock());

        uint256 accumulated = blocks.mul(getMetricPerBlock());

        _lifetimeShareValue = _lifetimeShareValue.add(accumulated.mul(ACC_METRIC_PRECISION).div(_totalAllocPoint));
        setLastRewardBlock(block.number);
    }

    function claim(uint256 stakeIndex) public {
        Staker storage stake = _stakes[stakeIndex];

        require(stake.claimable != 0, "No claimable rewards to withdraw");
        require(stake.stakeAddress == _msgSender(), "Sender can not claim");
        _metric.transfer(stake.stakeAddress, stake.claimable);
        stake.claimable = 0;

        emit Withdraw(msg.sender, stakeIndex, stake.claimable);
    }

// --------------------------------------------------------------------- Structs
    struct Staker {
        address stakeAddress;
        uint256 metricAmount;
        uint256 rewardDebt; // keeps track of how much the user is owed or has been credited already
        uint256 claimable;
        uint256 startDate;
    }
}


