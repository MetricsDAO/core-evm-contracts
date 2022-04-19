//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./MetricToken.sol";

// Heavily Inspired by Sushi's MasterChefv2 - but with a few changes:
// - We don't have a v1, so we don't need that wrapping
// - We don't have two layers (pools and users), so the concept of pools is flattened into the contract itself.
// ^^ This is because METRIC is the only token this will ever work with.

// Read this: https://dev.sushi.com/sushiswap/contracts/masterchefv2
// Also read this: https://soliditydeveloper.com/sushi-swap

contract Allocator is AccessControl {
    using SafeMath for uint256;

    bytes32 public constant ALLOCATION_ROLE = keccak256("ALLOCATION_ROLE");

    uint256 public METRIC_PER_BLOCK = 4 * 10**18;
    uint256 public constant ACC_METRIC_PRECISION = 1e12;

    bool private _rewardsActive;
    AllocationGroup[] private _allocations;
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
            pending: 0
        });

        _allocations.push(group);
        _totalAllocPoint = _totalAllocPoint.add(group.shares);
    }

    function updateAllocationGroup(
        uint256 agIndex,
        uint256 shares,
        bool newAutoDistribute
    ) public onlyRole(ALLOCATION_ROLE) {
        _totalAllocPoint = _totalAllocPoint.sub(_allocations[agIndex].shares).add(shares);
        _allocations[agIndex].shares = shares;
        _allocations[agIndex].autodistribute = newAutoDistribute;
    }

    function removeAllocationGroup(uint256 agIndex) external onlyRole(ALLOCATION_ROLE) {
        require(agIndex < _allocations.length);
        _totalAllocPoint = _totalAllocPoint.sub(_allocations[agIndex].shares);

        _allocations[agIndex] = _allocations[_allocations.length - 1];
        _allocations.pop();
    }

    function toggleRewards(bool isOn) external onlyRole(ALLOCATION_ROLE) {
        _rewardsActive = isOn;
        _lastRewardBlock = block.number;
    }

    //------------------------------------------------------Getters

    function getAllocationGroups() public view returns (AllocationGroup[] memory) {
        return _allocations;
    }

    function getTotalAllocationPoints() public view returns (uint256) {
        return _totalAllocPoint;
    }

    //------------------------------------------------------Distribution

    function viewPendingAllocations(uint256 agIndex) public view returns (uint256) {
        AllocationGroup storage group = _allocations[agIndex];

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
        for (uint256 i = 0; i < _allocations.length; i++) {
            harvest(i);
        }
    }

    function harvest(uint256 agIndex) public {
        AllocationGroup storage group = _allocations[agIndex];

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
    }
}
