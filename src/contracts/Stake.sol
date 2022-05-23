//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./MetricToken.sol";

//TODO make this inherit from Chef
contract Stake {
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

        function stake(
        address newAddress,
        uint256 metricAmount,
        bool newAutoDistribute,
        uint256 newStartDate
    ) external nonDuplicated(newAddress) {
        if (_rewardsActive && _totalAllocPoint > 0) {
            updateStaker();
        }
        Staker memory group = Staker({
            stakerAddress: newAddress,
            shares: metricAmount,
            autodistribute: newAutoDistribute,
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
            updateAccumulatedAllocations();
        }
        _totalAllocPoint = _totalAllocPoint.sub(_stakers[stakerIndex].shares).add(shares);
        _stakers[stakerIndex].groupAddress = groupAddress;
        _stakers[stakerIndex].shares = shares;
    }

    // function removeAllocationGroup(uint256 agIndex) external onlyRole(ALLOCATION_ROLE) {
    //     require(agIndex < _allocations.length);
    //     if (_rewardsActive && _totalAllocPoint > 0) {
    //         updateAccumulatedAllocations();
    //     }
    //     _totalAllocPoint = _totalAllocPoint.sub(_allocations[agIndex].shares);

    //     _allocations[agIndex] = _allocations[_allocations.length - 1];
    //     _allocations.pop();
    // }

    // function toggleRewards(bool isOn) external onlyRole(ALLOCATION_ROLE) {
    //     _rewardsActive = isOn;
    //     _lastRewardBlock = block.number;
    // }

    // function stakeMetric(uint256 metricAmount) public payable {

    // }

    // function stakeAdditionalMetric(uint256 metricAmount) public payable {

    // }

    function claim(uint256 stakerIndex) public {
        Staker[] storage group = _stakers[stakerIndex];

        require(group.claimable != 0, "No claimable rewards to withdraw");
        // TODO do we want a backup in case a group loses access to their wallet
        require(group.groupAddress == _msgSender(), "Sender can not claim another address' metric");
        _metric.transfer(group.groupAddress, group.claimable);
        group.claimable = 0;

        emit Withdraw(msg.sender, stakerIndex, group.claimable);
    }

    event Harvest(address harvester, uint256 agIndex, uint256 amount);
    event Withdraw(address withdrawer, uint256 agIndex, uint256 amount);

// --------------------------------------------------------------------- Structs
    struct Staker {
        address stakerAddress;
        uint256 metricAmount;
        bool autodistribute;
        uint256 rewardDebt; // keeps track of how much the user is owed or has been credited already
        uint256 claimable;
        uint256 startDate;
    }
}
//payable staking function
//withdrawl function

