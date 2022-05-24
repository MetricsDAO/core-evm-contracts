//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Chef.sol";
import "./MetricToken.sol";

//TODO StakeMetric, updateStaker, removeStaker, updateAccumulatedStakingRewards, and Claim can be moved to Chef
//TODO Iron out logic for stakeAdditionalMetric function
//TODO Allow staker to withdrawl principal

contract StakingChef is Chef {
    using SafeMath for uint256;
    uint256 public _metricPerBlock;
    uint256 public constant ACC_METRIC_PRECISION = 1e12;

    bool private _rewardsActive;
    Staker[] private _stakes;
    uint256 private _totalAllocPoint;
    uint256 private _lifetimeShareValue = 0;
    uint256 private _lastRewardBlock;

     MetricToken private _metric;

    function setMetricPerBlock(uint256 metricAmount) public {
        _metricPerBlock = metricAmount * 10**18;
    }

    mapping(address => bool) public addressExistence;
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
        if (_rewardsActive && _totalAllocPoint > 0) {
            updateStaker();
        }
        Staker memory stake = Staker({
            stakerAddress: newAddress,
            principalMetric: metricAmount, 
            startDate: newStartDate,
            rewardDebt: metricAmount.mul(_lifetimeShareValue).div(ACC_METRIC_PRECISION),
            claimable: 0
        });

        _stakes.push(stake);
        _totalAllocPoint = _totalAllocPoint.add(stake.principalMetric);
        _metric.transfer(address(this), stake.principalMetric);
        
    }

    function updateStaker(
        address stakeAddress,
        uint256 stakeIndex,
        uint256 principalMetric //is there a better name for this?
    ) public {
        if (_rewardsActive && _totalAllocPoint > 0) {
            updateAccumulatedStakingRewards();
        }
        _totalAllocPoint = _totalAllocPoint.sub(_stakes[stakeIndex].principalMetric).add(principalMetric);
        _stakes[stakeIndex].stakeAddress = stakeAddress;
        _stakes[stakeIndex].principalMetric = principalMetric;
    }

    function removeStaker(uint256 stakeIndex) external {
        require(stakeIndex.stakeAddress == _msgSender(), "Can only remove self");
        require(stakeIndex < _stakes.length);
        if (_rewardsActive && _totalAllocPoint > 0) {
            updateAccumulatedStakingRewards();
        }
        _totalAllocPoint = _totalAllocPoint.sub(_stakes[stakeIndex].principalMetric);

        _stakes[stakeIndex] = _stakes[_stakes.length - 1];
        _stakes.pop();
    }

    function toggleRewards() public virtual override {
        Chef.toggleRewards();
    }

    function stakeAdditionalMetric(
        address stakeAddress,
        uint256 metricAmount,
        uint256 newStartDate
    ) public {
        // uint256 totalMetricStaked = metricAmount + 

        Staker memory stake = Staker({
            stakeAddress: stakeAddress,
            // metricAmount: 
            startDate: newStartDate,
            rewardDebt: metricAmount.mul(_lifetimeShareValue).div(ACC_METRIC_PRECISION),
            claimable: 0
            });

            _stakes.push(stake);
            _totalAllocPoint = _totalAllocPoint.add(stake.shares);
            _metric.transfer(address(this), stake.metricAmount);
    }

        function updateAccumulatedStakingRewards() public {
        require(_rewardsActive, "Rewards are not active");
        if (block.number <= _lastRewardBlock) {
            return;
        }

        // TODO confirm budget is correct with assertions
        // Not sure we can project emission rate over X years?
        // Not entirely sure how to handle this, but we can at least try to make it work.
        // ^^ will help with fuzz testing

        uint256 blocks = block.number.sub(_lastRewardBlock);

        uint256 accumulated = blocks.mul(_metricPerBlock);

        _lifetimeShareValue = _lifetimeShareValue.add(accumulated.mul(ACC_METRIC_PRECISION).div(_totalAllocPoint));
        _lastRewardBlock = block.number;
    }

    function claim(uint256 stakeIndex) public {
        Staker[] storage stake = _stakes[stakeIndex];

        require(stake.claimable != 0, "No claimable rewards to withdraw");
        require(stake.stakeAddress == _msgSender(), "Sender can not claim");
        _metric.transfer(stake.stakeAddress, stake.claimable);
        stake.claimable = 0;

        emit Withdraw(msg.sender, stakeIndex, stake.claimable);
    }

    event Withdraw(address withdrawer, uint256 agIndex, uint256 amount);

// --------------------------------------------------------------------- Structs
    struct Staker {
        address stakerAddress;
        uint256 metricAmount;
        uint256 rewardDebt; // keeps track of how much the user is owed or has been credited already
        uint256 claimable;
        uint256 startDate;
    }
}


