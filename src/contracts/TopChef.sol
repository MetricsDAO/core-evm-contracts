//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Chef.sol";

contract TopChef is Chef {
    using SafeMath for uint256;
    AllocationGroup[] private _allocations;

    constructor(address metricTokenAddress) {
        setMetricToken(metricTokenAddress);
        setMetricPerBlock(4);
        toggleRewards(false); // locking contract initially
    }

    //------------------------------------------------------Manage Allocation Groups

    function addAllocationGroup(
        address newAddress,
        uint256 newShares,
        bool newAutoDistribute
    ) external onlyOwner nonDuplicated(newAddress) {
        require(newShares > 0, "shares should be greater than 0");
        if (areRewardsActive() && getTotalAllocationShares() > 0) {
            updateAccumulatedAllocations();
        }

        AllocationGroup memory group = AllocationGroup({
            groupAddress: newAddress,
            shares: newShares,
            autodistribute: newAutoDistribute,
            rewardDebt: newShares.mul(getLifetimeShareValue()).div(ACC_METRIC_PRECISION),
            claimable: 0
        });

        _allocations.push(group);
        addTotalAllocShares(group.shares);
    }

    // TODO do we actually need to do this?
    function updateAllocationGroup(
        address groupAddress,
        uint256 agIndex,
        uint256 shares,
        bool newAutoDistribute
    ) public onlyOwner {
        require(areRewardsActive(), "Rewards are not active");
        harvest(agIndex);
        addTotalAllocShares(_allocations[agIndex].shares, shares);
        _allocations[agIndex].groupAddress = groupAddress;
        _allocations[agIndex].shares = shares;
        _allocations[agIndex].autodistribute = newAutoDistribute;
    }

    function removeAllocationGroup(uint256 agIndex) external onlyOwner {
        require(agIndex < _allocations.length, "Index does not match allocation");
        require(areRewardsActive(), "Rewards are not active");
        _allocations[agIndex].autodistribute = true;
        harvest(agIndex);

        removeAllocShares(_allocations[agIndex].shares);

        _allocations[agIndex] = _allocations[_allocations.length - 1];
        _allocations.pop();
    }

    //------------------------------------------------------Getters

    function getAllocationGroups() public view returns (AllocationGroup[] memory) {
        return _allocations;
    }

    //------------------------------------------------------Distribution

    function viewPendingHarvest(uint256 agIndex) public view returns (uint256) {
        AllocationGroup memory group = _allocations[agIndex];
        if (areRewardsActive()) {
            return group.shares.mul(getLifeTimeShareValueEstimate()).div(ACC_METRIC_PRECISION).sub(group.rewardDebt);
        }
        return group.shares.mul(getLifetimeShareValue()).div(ACC_METRIC_PRECISION).sub(group.rewardDebt);
    }

    function viewPendingClaims(uint256 agIndex) public view returns (uint256) {
        AllocationGroup memory group = _allocations[agIndex];

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

        setLifetimeShareValue();
        setLastRewardBlock(block.number);
    }

    // TODO when we implement the emission rate, ensure this function is called before update the rate
    // if we don't, then a user's rewards pre-emission change will incorrectly reflect the new rate
    function harvestAll() external onlyOwner {
        for (uint8 i = 0; i < _allocations.length; i++) {
            harvest(i);
        }
    }

    function harvest(uint256 agIndex) public {
        require(areRewardsActive(), "Rewards are not active");
        AllocationGroup storage group = _allocations[agIndex];
        // TODO do we want a backup in case a group looses access to their wallet
        require(group.groupAddress == _msgSender() || _msgSender() == owner(), "Sender is not group or owner");

        updateAccumulatedAllocations();

        uint256 claimable = group.shares.mul(getLifetimeShareValue()).div(ACC_METRIC_PRECISION).sub(group.rewardDebt);

        group.rewardDebt = group.rewardDebt.add(claimable);
        if (claimable != 0) {
            if (group.autodistribute) {
                SafeERC20.safeTransfer(IERC20(getMetricToken()), group.groupAddress, claimable);
                group.claimable = 0;
            } else {
                group.claimable = group.claimable.add(claimable);
            }
        }
        emit Harvest(msg.sender, agIndex, claimable);
    }

    function claim(uint256 agIndex) external {
        require(areRewardsActive(), "Rewards are not active");
        AllocationGroup storage group = _allocations[agIndex];

        require(group.claimable != 0, "No claimable rewards to withdraw");
        // TODO do we want a backup in case a group looses access to their wallet
        require(group.groupAddress == _msgSender(), "Sender does not represent group");
        SafeERC20.safeTransfer(IERC20(getMetricToken()), group.groupAddress, group.claimable);
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
