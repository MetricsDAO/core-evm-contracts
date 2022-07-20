//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Chef.sol";

contract TopChef is Chef {
    AllocationGroup[] private _allocations;

    constructor(address metricTokenAddress) {
        setMetricToken(metricTokenAddress);
        setMetricPerBlock(4);
        toggleRewards(false); // locking contract initially
    }

    //------------------------------------------------------Manage Allocation Groups

    function addAllocationGroup(address newAddress, uint256 newShares) external onlyOwner nonDuplicated(newAddress) {
        // Checks
        if (newShares <= 0) revert SharesNotGreaterThanZero();
        if (areRewardsActive() && getTotalAllocationShares() > 0) {
            updateAccumulatedAllocations();
        }

        // Effects
        AllocationGroup memory group = AllocationGroup({
            groupAddress: newAddress,
            shares: newShares,
            lifetimeEarnings: (newShares * _getLifetimeShareValue()) / ACC_METRIC_PRECISION,
            claimable: 0
        });

        _allocations.push(group);
        _addTotalAllocShares(group.shares);

        emit AddGroup(group);
    }

    // TODO do we actually need to do this?
    function updateAllocationGroup(
        address groupAddress,
        uint256 agIndex,
        uint256 shares
    ) public activeRewards validIndex(agIndex) onlyOwner {
        // Checks (modifier)
        if (shares <= 0) revert SharesNotGreaterThanZero();

        // Effects
        harvest(agIndex);

        AllocationGroup storage group = _allocations[agIndex];
        _addTotalAllocShares(group.shares, shares);
        group.groupAddress = groupAddress;
        group.shares = shares;

        emit UpdateGroup(group);
    }

    function removeAllocationGroup(uint256 agIndex) external validIndex(agIndex) activeRewards onlyOwner {
        // Effects
        harvest(agIndex);
        AllocationGroup memory group = _allocations[agIndex];

        uint256 claimable = group.claimable;

        _removeAllocShares(_allocations[agIndex].shares);
        _allocations[agIndex] = _allocations[_allocations.length - 1];
        _allocations.pop();

        // Interactions
        if (claimable > 0) {
            SafeERC20.safeTransfer(IERC20(getMetricToken()), group.groupAddress, claimable);
            emit Withdraw(group.groupAddress, agIndex, claimable);
        }
        emit RemoveGroup(group);
    }

    //------------------------------------------------------Getters

    function getAllocationGroups() public view returns (AllocationGroup[] memory) {
        return _allocations;
    }

    //------------------------------------------------------Distribution

    function viewPendingHarvest(uint256 agIndex) public view validIndex(agIndex) returns (uint256) {
        AllocationGroup memory group = _allocations[agIndex];

        if (areRewardsActive()) {
            return ((group.shares * (getLifeTimeShareValueEstimate())) / ACC_METRIC_PRECISION) - group.lifetimeEarnings;
        } else {
            return (group.shares * (_getLifetimeShareValue())) / ACC_METRIC_PRECISION - group.lifetimeEarnings;
        }
    }

    function viewPendingClaims(uint256 agIndex) public view validIndex(agIndex) returns (uint256) {
        AllocationGroup memory group = _allocations[agIndex];

        return group.claimable;
    }

    function viewPendingRewards(uint256 agIndex) public view validIndex(agIndex) returns (uint256) {
        AllocationGroup memory group = _allocations[agIndex];
        uint256 claimable = group.claimable;
        uint256 harvestable = viewPendingHarvest(agIndex);
        return claimable + harvestable;
    }

    function updateAccumulatedAllocations() public activeRewards {
        if (block.number <= getLastRewardBlock()) {
            return;
        }

        setLifetimeShareValue();
    }

    // TODO when we implement the emission rate, ensure this function is called before update the rate
    // if we don't, then a user's rewards pre-emission change will incorrectly reflect the new rate
    function harvestAll() external onlyOwner {
        for (uint8 i = 0; i < _allocations.length; ++i) {
            harvest(i);
        }
    }

    function harvest(uint256 agIndex) public activeRewards validIndex(agIndex) returns (uint256) {
        AllocationGroup storage group = _allocations[agIndex];

        // Effects
        updateAccumulatedAllocations();
        uint256 toClaim = ((group.shares * (_getLifetimeShareValue())) / ACC_METRIC_PRECISION) - group.lifetimeEarnings;

        group.lifetimeEarnings = group.lifetimeEarnings + toClaim;
        uint256 totalClaimable = group.claimable + toClaim;
        group.claimable = totalClaimable;

        if (toClaim > 0) {
            emit Harvest(_msgSender(), agIndex, toClaim);
        }
        return totalClaimable;
    }

    function claim(uint256 agIndex) public validIndex(agIndex) {
        AllocationGroup storage group = _allocations[agIndex];
        uint256 claimable = harvest(agIndex);
        if (claimable != 0) {
            group.claimable = 0;
            SafeERC20.safeTransfer(IERC20(getMetricToken()), group.groupAddress, claimable);
            emit Withdraw(group.groupAddress, agIndex, claimable);
        }
    }

    //------------------------------------------------------Structs

    struct AllocationGroup {
        address groupAddress;
        uint256 shares;
        uint256 lifetimeEarnings; // keeps track of how much the user is owed or has been credited already
        uint256 claimable;
    }

    //------------------------------------------------------ Errors
    error SharesNotGreaterThanZero();
    error IndexDoesNotMatchAllocation();

    // --------------------------------------------------------------------- Events
    event RemoveGroup(TopChef.AllocationGroup);
    event AddGroup(TopChef.AllocationGroup);
    event UpdateGroup(TopChef.AllocationGroup);

    //------------------------------------------------------ Modifiers
    // modifier activeRewards() {
    //     if (!areRewardsActive()) revert RewardsInactive();
    //     _;
    // }

    modifier validIndex(uint256 agIndex) {
        if (agIndex >= _allocations.length) revert IndexDoesNotMatchAllocation();
        _;
    }
}
