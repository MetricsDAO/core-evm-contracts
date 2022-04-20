//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./MetricToken.sol";

// Heavily Inspired by Sushi's MasterChefv2 - but with a few changes:
// - We don't have a v1, so we don't need that wrapping
// - We don't have two layers (pools and users), so the concept of pools is flattened into the contract itself.
// ^^ This is because METRIC is the only token this will ever work with.

// Read this: https://dev.sushi.com/sushiswap/contracts/masterchefv2
// Also read this: https://soliditydeveloper.com/sushi-swap

/**
 In sushi's master chef, the design allows the controller to submit LP contracts for yield farming, and then user's can stake their LP tokens.

 In this contract, there is no concept of a user staking their LP tokens - and instead of LP contract, the controller is submitting Allocation Groups.

 So in sushi:

 1.  Every `x` blocks, calculate minted Sushi Tokens for each LP contract based on their (shares / total shares)
 2.  Then, do the math to figure out how many rewards each LP token is worth (based on the total amount of LP tokens staked)
 3.  Then, when a user requests their rewards, their pending amount is based on how many tokens they have staked - and from the previous step, we know how many rewards each LP token gets.
 4.  Historical withdrawals are tracked through "rewardDebt" - so subtract the amount of rewards they have already claimed from their total earned rewards.


This contract is a bit more simplified.  Basically there are no LP tokens - so those values are tracked at the top level.

 1.  Every `x` blocks, calculate  METRIC Tokens for each AG based on their (shares / total shares)
 2.  Then, do the math to figure out how many METRIC tokens will be distributed in total
 3.  Then, when a user requests their rewards, their pending amount is based on how many shares they have - and from the previous step, we know how many rewards each AG group gets.
 4.  Historical withdrawals are tracked through "rewardDebt" - so subtract the amount of rewards they have already claimed from their total earned rewards.


 */

contract Allocator is AccessControl {
    using SafeMath for uint256;

    bytes32 public constant ALLOCATION_ROLE = keccak256("ALLOCATION_ROLE");

    uint256 public METRIC_PER_BLOCK = 4 * 10**18;
    uint256 public constant ACC_METRIC_PRECISION = 1e12;

    uint256 public _numberOfAllocationGroups;
    bool private _rewardsActive;
    mapping(uint => AllocationGroup) private _allocationGroups;
    // AllocationGroup[] private _allocationGroups;
    uint256 private _totalAllocPoint;
    uint256 private _accMETRICPerShare = 0;
    uint256 private _lastRewardBlock;

    MetricToken private _metric;

    constructor(MetricToken metric) {
        _metric = metric;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ALLOCATION_ROLE, msg.sender);
    }

    //------------------------------------------------------Manage Allocation Groups

    function addAllocationGroup(
        address newAddress,
        uint256 newShares,
        bool newAutoDistribute
    ) external onlyRole(ALLOCATION_ROLE) nonDuplicated(newAddress) {
        AllocationGroup memory group = AllocationGroup({
            groupAddress: newAddress,
            shares: newShares,
            autodistribute: newAutoDistribute,
            rewardDebt: 0,
            pending: 0,
            isActive: true
        });

        _allocationGroups[_numberOfAllocationGroups] = group;
        _numberOfAllocationGroups++;
        _totalAllocPoint = _totalAllocPoint.add(group.shares);
    }

    function updateAllocationGroup(
        uint256 agIndex,
        uint256 shares,
        bool newAutoDistribute
    ) public onlyRole(ALLOCATION_ROLE) {
        _totalAllocPoint = _totalAllocPoint.sub(_allocationGroups[agIndex].shares).add(shares);
        _allocationGroups[agIndex].shares = shares;
        _allocationGroups[agIndex].autodistribute = newAutoDistribute;
    }

    function updateAllocationGroupShares(
        uint256 agIndex,
        uint256 newShares
    ) public onlyRole(ALLOCATION_ROLE) {
        _totalAllocPoint = _totalAllocPoint.sub(_allocationGroups[agIndex].shares).add(newShares);
        _allocationGroups[agIndex].shares = newShares;
    }

    function updateAllocationGroupAutoDistribute(
        uint256 agIndex,
        bool newAutoDistribute
    ) public onlyRole(ALLOCATION_ROLE) {
        _allocationGroups[agIndex].autodistribute = newAutoDistribute;
    }

    function updateAllocationGroupStatus(
        uint256 agIndex,
        bool isActive
    ) public onlyRole(ALLOCATION_ROLE) {
        _allocationGroups[agIndex].isActive = isActive;
    }

    
    // TODO: replace with a function that toggles active status of the allocation group
    // function removeAllocationGroup(uint256 agIndex) external onlyRole(ALLOCATION_ROLE) {
    //     require(agIndex < _allocationGroups.length);
    //     _totalAllocPoint = _totalAllocPoint.sub(_allocationGroups[agIndex].shares);

    //     _allocationGroups[agIndex] = _allocationGroups[_allocationGroups.length - 1];
    //     _allocationGroups.pop();
    // }

    function toggleRewards(bool isOn) external onlyRole(ALLOCATION_ROLE) {
        _rewardsActive = isOn;
        _lastRewardBlock = block.number;
    }

    //------------------------------------------------------Getters

    function getAllocationGroup(uint index) public view returns (AllocationGroup memory) {
        return _allocationGroups[index];
    }
    

    function getTotalAllocationPoints() public view returns (uint256) {
        return _totalAllocPoint;
    }

    //------------------------------------------------------Distribution

    function viewPendingAllocations(uint256 agIndex) public view returns (uint256) {
        AllocationGroup storage group = _allocationGroups[agIndex];

        return group.shares.mul(_accMETRICPerShare).div(ACC_METRIC_PRECISION).sub(group.rewardDebt);
    }

    function updateAccumulatedAllocations() public {
        require(_rewardsActive, "Rewards are not active");
        if (block.number <= _lastRewardBlock) {
            return;
        }

        // TODO confirm budget is correct with assertions
        // Not sure we can project emission rate over X years?
        // Not entirely sure how to handle this, but we can at least try to make it work.
        // ^^ will help with fuzz testing

        uint256 blocks = block.number.sub(_lastRewardBlock);

        uint256 accumulated = blocks.mul(METRIC_PER_BLOCK);

        _accMETRICPerShare = _accMETRICPerShare.add(accumulated.mul(ACC_METRIC_PRECISION).div(_totalAllocPoint));
        _lastRewardBlock = block.number;
    }

    function harvestAll() public {
        for (uint256 i = 0; i < _numberOfAllocationGroups; i++) {
            harvest(i);
        }
    }

    function harvest(uint256 agIndex) public {
        AllocationGroup storage group = _allocationGroups[agIndex];
        require(group.isActive, "Allocation group is not active");
        updateAccumulatedAllocations();

        uint256 pending = group.shares.mul(_accMETRICPerShare).div(ACC_METRIC_PRECISION).sub(group.rewardDebt);

        group.rewardDebt = pending;
        if (pending != 0) {
            if (!group.autodistribute) {
                group.pending = group.pending.add(pending);
            } else {
                _metric.transfer(group.groupAddress, pending);
            }
        }

        emit Harvest(msg.sender, agIndex, pending);
    }

    //------------------------------------------------------Support Functions

    mapping(address => bool) public addressExistence;
    modifier nonDuplicated(address _address) {
        require(addressExistence[_address] == false, "nonDuplicated: duplicated");
        addressExistence[_address] = true;
        _;
    }

    //------------------------------------------------------Structs

    event Harvest(address harvester, uint256 agIndex, uint256 amount);

    struct AllocationGroup {
        address groupAddress;
        uint256 shares;
        bool autodistribute;
        uint256 rewardDebt; // keeps track of how much the user is owed or has been credited already
        uint256 pending;
        bool isActive;
    }
}