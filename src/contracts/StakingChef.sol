//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Chef.sol";
import "./MetricToken.sol";

//TODO StakeMetric, updateStaker, removeStaker, updateAccumulatedStakingRewards, and Claim can be moved to Chef
//TODO Iron out logic for stakeMetric, and stakeAdditionalMetric function

contract StakingChef is Chef {
    using SafeMath for uint256;
    uint256 public _metricPerBlock;
    uint256 public constant ACC_METRIC_PRECISION = 1e12;

    bool private _rewardsActive;
    Staker[] private _stakers;
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
        Staker memory group = Staker({
            stakerAddress: newAddress,
            //TODO figure out what value shares should be
            shares: metricAmount,  //Don't think metricAmount is the correct value here same as in reward debt
            startDate: newStartDate,
            rewardDebt: metricAmount.mul(_lifetimeShareValue).div(ACC_METRIC_PRECISION),
            claimable: 0
        });

        _stakers.push(group);
        _totalAllocPoint = _totalAllocPoint.add(group.shares);
    }

    function updateStaker(
        address groupAddress,
        uint256 stakerIndex,
        uint256 shares
    ) public {
        if (_rewardsActive && _totalAllocPoint > 0) {
            updateAccumulatedStakingRewards();
        }
        _totalAllocPoint = _totalAllocPoint.sub(_stakers[stakerIndex].shares).add(shares);
        _stakers[stakerIndex].groupAddress = groupAddress;
        _stakers[stakerIndex].shares = shares;
    }

    function removeStaker(uint256 stakerIndex) external {
        require(stakerIndex.stakerAddress == _msgSender(), "Can only remove self");
        require(stakerIndex < _stakers.length);
        if (_rewardsActive && _totalAllocPoint > 0) {
            updateAccumulatedStakingRewards();
        }
        _totalAllocPoint = _totalAllocPoint.sub(_stakers[stakerIndex].shares);

        _stakers[stakerIndex] = _stakers[_stakers.length - 1];
        _stakers.pop();
    }

    function toggleRewards() public virtual override {
    Chef.toggleRewards();
    }

    function stakeAdditionalMetric(
        address stakerAddress,
        uint256 metricAmount,
        uint256 newStartDate
        ) public {
    Staker memory group = Staker({
        stakerAddress: stakerAddress,
        //TODO figure out what value shares should be
        shares: metricAmount + staker.metricAmount, //this logic is probably incorrect will need staker index to get current amount of metric staked
        startDate: newStartDate,
        rewardDebt: metricAmount.mul(_lifetimeShareValue).div(ACC_METRIC_PRECISION),
        claimable: 0
        });

        _stakers.push(group);
        _totalAllocPoint = _totalAllocPoint.add(group.shares);
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

    function claim(uint256 stakerIndex) public {
        Staker[] storage group = _stakers[stakerIndex];

        require(group.claimable != 0, "No claimable rewards to withdraw");
        // TODO do we want a backup in case a group loses access to their wallet
        require(group.groupAddress == _msgSender(), "Sender can not claim");
        _metric.transfer(group.groupAddress, group.claimable);
        group.claimable = 0;

        emit Withdraw(msg.sender, stakerIndex, group.claimable);
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


