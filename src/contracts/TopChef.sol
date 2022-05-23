//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Chef.sol";
import "./MetricToken.sol";

contract TopChef is Chef {
    using SafeMath for uint256;
    AllocationGroup[] private _allocations;
    uint256 private _totalAllocPoint;
    uint256 private _lifetimeShareValue;

    MetricToken private _metric;

    constructor(address metricTokenAddress) {
        _metric = MetricToken(metricTokenAddress);
        setMetricPerBlock(4);
    }

    //------------------------------------------------------Manage Allocation Groups

    function addAllocationGroup(
        address newAddress,
        uint256 newShares,
        bool newAutoDistribute
    ) external onlyOwner() nonDuplicated(newAddress) {
        if (areRewardsActive() && _totalAllocPoint > 0) {
            updateAccumulatedAllocations();
        }
        AllocationGroup memory group = AllocationGroup({
            groupAddress: newAddress,
            shares: newShares,
            autodistribute: newAutoDistribute,
            rewardDebt: newShares.mul(_lifetimeShareValue).div(ACC_METRIC_PRECISION),
            claimable: 0
        });

        _allocations.push(group);
        _totalAllocPoint = _totalAllocPoint.add(group.shares);
    }

    function updateAllocationGroup(
        address groupAddress,
        uint256 agIndex,
        uint256 shares,
        bool newAutoDistribute
    ) public onlyOwner() {
        if (areRewardsActive() && _totalAllocPoint > 0) {
            updateAccumulatedAllocations();
        }
        _totalAllocPoint = _totalAllocPoint.sub(_allocations[agIndex].shares).add(shares);
        _allocations[agIndex].groupAddress = groupAddress;
        _allocations[agIndex].shares = shares;
        _allocations[agIndex].autodistribute = newAutoDistribute;
    }

    function removeAllocationGroup(uint256 agIndex) external onlyOwner() {
        require(agIndex < _allocations.length, "Index does not match allocation");
        if (areRewardsActive() && _totalAllocPoint > 0) {
            updateAccumulatedAllocations();
        }
        _totalAllocPoint = _totalAllocPoint.sub(_allocations[agIndex].shares);

        _allocations[agIndex] = _allocations[_allocations.length - 1];
        _allocations.pop();
    }

    //------------------------------------------------------Getters

    function getAllocationGroups() public view returns (AllocationGroup[] memory) {
        return _allocations;
    }

    function getTotalAllocationPoints() public view returns (uint256) {
        return _totalAllocPoint;
    }

    function getLifetimeShareValue () public view returns (uint256) {
        return _lifetimeShareValue;
    }

    //------------------------------------------------------Distribution

    function viewPendingHarvest(uint256 agIndex) public view returns (uint256) {
        AllocationGroup storage group = _allocations[agIndex];

        return group.shares.mul(_lifetimeShareValue).div(ACC_METRIC_PRECISION).sub(group.rewardDebt);
    }

    function viewPendingClaims(uint256 agIndex) public view returns (uint256) {
        AllocationGroup storage group = _allocations[agIndex];

        return group.claimable;
    }

    function updateAccumulatedAllocations() public {
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

    // TODO when we implement the emission rate, ensure this function is called before update the rate
    // if we don't, then a user's rewards pre-emission change will incorrectly reflect the new rate
    function harvestAll() external {
        for (uint8 i = 0; i < _allocations.length; i++) {
            harvest(i);
        }
    }

    function harvest(uint256 agIndex) public {
        AllocationGroup storage group = _allocations[agIndex];

        updateAccumulatedAllocations();

        uint256 claimable = group.shares.mul(_lifetimeShareValue).div(ACC_METRIC_PRECISION).sub(group.rewardDebt);

        group.rewardDebt = claimable;
        if (claimable != 0) {
            if (group.autodistribute) {
                _metric.transfer(group.groupAddress, claimable);
                group.claimable = 0;
            } else {
                group.claimable = group.claimable.add(claimable);
            }
        }
        emit Harvest(msg.sender, agIndex, claimable);
    }

    function claim(uint256 agIndex) external {
        AllocationGroup storage group = _allocations[agIndex];

        require(group.claimable != 0, "No claimable rewards to withdraw");
        // TODO do we want a backup in case a group looses access to their wallet
        require(group.groupAddress == _msgSender(), "Sender does not represent group");
        _metric.transfer(group.groupAddress, group.claimable);
        group.claimable = 0;

        emit Withdraw(msg.sender, agIndex, group.claimable);
    }

    //------------------------------------------------------Structs

    struct AllocationGroup {
        address groupAddress;
        uint256 shares;
        bool autodistribute;
        uint256 rewardDebt; // keeps track of how much the user is owed or has been credited already
        uint256 claimable;
    }
}