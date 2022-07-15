//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

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
        if (!(newShares > 0)) revert SharesNotGreaterThanZero();
        if (areRewardsActive() && getTotalAllocationShares() > 0) {
            updateAccumulatedAllocations();
        }

        // Effects
        AllocationGroup memory group = AllocationGroup({
            groupAddress: newAddress,
            shares: newShares,
            rewardDebt: (newShares * getLifetimeShareValue()) / ACC_METRIC_PRECISION,
            claimable: 0
        });

        _allocations.push(group);
        addTotalAllocShares(group.shares);
    }

    // TODO do we actually need to do this?
    function updateAllocationGroup(
        address groupAddress,
        uint256 agIndex,
        uint256 shares
    ) public activeRewards onlyOwner {
        // Checks (modifier)

        // Effects
        harvest(agIndex);
        addTotalAllocShares(_allocations[agIndex].shares, shares);
        _allocations[agIndex].groupAddress = groupAddress;
        _allocations[agIndex].shares = shares;
    }

    function removeAllocationGroup(uint256 agIndex) external activeRewards onlyOwner {
        // Checks
        if (agIndex >= _allocations.length) revert IndexDoesNotMatchAllocation();

        // Effects
        harvest(agIndex);
        AllocationGroup memory group = _allocations[agIndex];

        uint256 claimable = group.claimable;

        removeAllocShares(_allocations[agIndex].shares);
        _allocations[agIndex] = _allocations[_allocations.length - 1];
        _allocations.pop();

        // Interactions
        if (claimable > 0) {
            SafeERC20.safeTransfer(IERC20(getMetricToken()), group.groupAddress, claimable);
            emit Withdraw(group.groupAddress, agIndex, claimable);
        }
    }

    //------------------------------------------------------Getters

    function getAllocationGroups() public view returns (AllocationGroup[] memory) {
        return _allocations;
    }

    //------------------------------------------------------Distribution

    function viewPendingHarvest(uint256 agIndex) public view returns (uint256) {
        AllocationGroup memory group = _allocations[agIndex];

        if (areRewardsActive()) {
            return ((group.shares * (getLifeTimeShareValueEstimate())) / ACC_METRIC_PRECISION) - group.rewardDebt;
        } else {
            return (group.shares * (getLifetimeShareValue())) / ACC_METRIC_PRECISION - group.rewardDebt;
        }
    }

    function viewPendingClaims(uint256 agIndex) public view returns (uint256) {
        AllocationGroup memory group = _allocations[agIndex];

        return group.claimable;
    }

    function viewPendingRewards(uint256 agIndex) public view returns (uint256) {
        AllocationGroup memory group = _allocations[agIndex];
        uint256 claimable = group.claimable;
        uint256 harvestable = viewPendingHarvest(agIndex);
        return claimable + harvestable;
    }

    function updateAccumulatedAllocations() public activeRewards {
        if (block.number <= getLastRewardBlock()) {
            return;
        }

        // TODO confirm budget is correct with assertions
        // Not sure we can project emission rate over X years?
        // Not entirely sure how to handle this, but we can at least try to make it work.
        // ^^ will help with fuzz testing

        setLifetimeShareValue();
        setLastRewardBlock(block.number);
    }

    // TODO when we implement the emission rate, ensure this function is called before update the rate
    // if we don't, then a user's rewards pre-emission change will incorrectly reflect the new rate
    function harvestAll() external onlyOwner {
        for (uint8 i = 0; i < _allocations.length; ++i) {
            harvest(i);
        }
    }

    function harvest(uint256 agIndex) public activeRewards returns (uint256) {
        // Checks
        AllocationGroup storage group = _allocations[agIndex];
        // TODO do we want a backup in case a group looses access to their wallet

        // Effects
        updateAccumulatedAllocations();
        uint256 toClaim = ((group.shares * (getLifetimeShareValue())) / ACC_METRIC_PRECISION) - group.rewardDebt;

        group.rewardDebt = group.rewardDebt + toClaim;
        uint256 totalClaimable = group.claimable + toClaim;
        group.claimable = totalClaimable;

        if (toClaim > 0) {
            emit Harvest(_msgSender(), agIndex, toClaim);
        }
        return totalClaimable;
    }

    function claim(uint256 agIndex) public {
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
        uint256 rewardDebt; // keeps track of how much the user is owed or has been credited already
        uint256 claimable;
    }

    //------------------------------------------------------ Errors
    error SharesNotGreaterThanZero();
    error IndexDoesNotMatchAllocation();
    error RewardsInactive();
    error NoClaimableRewardToWithdraw();
    error SenderDoesNotRepresentGroup();

    //------------------------------------------------------ Modifiers
    modifier activeRewards() {
        if (!(areRewardsActive())) revert RewardsInactive();
        _;
    }
}
