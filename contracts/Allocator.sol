//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./MetricToken.sol";
// TODO remove before prod
import "hardhat/console.sol";

contract Allocator is AccessControl {
    using SafeMath for uint256;

    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

    uint256 public METRIC_PER_BLOCK = 4 * 10**18;
    uint256 public constant ACC_METRIC_PRECISION = 1e12;

    AllocationGroup[] private _allocations;
    uint256 private _totalAllocPoint;
    uint256 private _accMETRICPerShare = 0;
    uint256 private _lastRewardBlock;

    MetricToken private _metric;

    constructor(MetricToken metric) {
        _metric = metric;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DISTRIBUTOR_ROLE, msg.sender);
        // TODO we probably want to turn on rewards after it's live and AGs are setup?
        _lastRewardBlock = block.number;
    }

    //------------------------------------------------------Manage Allocation Groups

    function addAllocationGroup(
        address newAddress,
        uint256 newShares,
        bool newAutoDistribute
    ) external onlyRole(DISTRIBUTOR_ROLE) nonDuplicated(newAddress) {
        AllocationGroup memory group = AllocationGroup({groupAddress: newAddress, shares: newShares, autodistribute: newAutoDistribute, rewardDebt: 0});

        _allocations.push(group);
        _totalAllocPoint = _totalAllocPoint.add(group.shares);
    }

    function updateAllocationGroup(
        uint256 agIndex,
        uint256 shares,
        bool newAutoDistribute
    ) public onlyRole(DISTRIBUTOR_ROLE) {
        _totalAllocPoint = _totalAllocPoint.sub(_allocations[agIndex].shares).add(shares);
        _allocations[agIndex].shares = shares;
        _allocations[agIndex].autodistribute = newAutoDistribute;
    }

    function removeAllocationGroup(uint256 agIndex) external onlyRole(DISTRIBUTOR_ROLE) {
        require(agIndex < _allocations.length);
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

    //------------------------------------------------------Distribution

    function viewPendingAllocations(uint256 agIndex) public view returns (uint256) {
        AllocationGroup storage group = _allocations[agIndex];

        return group.shares.mul(_accMETRICPerShare).div(ACC_METRIC_PRECISION).sub(group.rewardDebt);
    }

    function updateAllocations() public {
        // AllocationGroup storage group = _allocations[agIndex];

        if (block.number <= _lastRewardBlock) {
            return;
        }

        // TODO confirm budget is correct with assertions

        uint256 blocks = block.number.sub(_lastRewardBlock);

        uint256 metricReward = blocks.mul(METRIC_PER_BLOCK).div(_totalAllocPoint);

        // TODO if we mint, we mint here - else this is just bookkeeping.

        _accMETRICPerShare = _accMETRICPerShare.add(metricReward.mul(ACC_METRIC_PRECISION));
        _lastRewardBlock = block.number;
    }

    function harvest(uint256 pid) public {
        // PoolInfo storage pool = _poolInfo[pid];
        // UserInfo storage user = userInfo[pid][msg.sender];
        // updatePool(pid);
        // uint256 pending = user.amount.mul(pool.accMoonPerShare).div(1e12).sub(user.rewardDebt);
        // user.rewardDebt = pending;
        // if (pending != 0) {
        //     MOONDUST.transfer(_msgSender(), pending);
        // }
        // emit Harvest(msg.sender, pid, pending);
    }

    //------------------------------------------------------Support Functions

    mapping(address => bool) public addressExistence;
    modifier nonDuplicated(address _address) {
        require(addressExistence[_address] == false, "nonDuplicated: duplicated");
        addressExistence[_address] = true;
        _;
    }

    //------------------------------------------------------Structs

    struct AllocationGroup {
        address groupAddress;
        uint256 shares;
        bool autodistribute;
        // uint256 lastRewardBlock;
        uint256 rewardDebt; // Reward Debt is modelled after Sushi's MasterChefv2
        // uint256 accMETRICPerShare;
    }
}
