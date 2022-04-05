//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./MetricToken.sol";

contract Allocator is AccessControl {
    using SafeMath for uint256;

    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

    uint256 private METRIC_PER_BLOCK = 4 * 10**18;
    uint256 private constant ACC_METRIC_PRECISION = 1e12;

    AllocationGroup[] private _allocations;
    uint256 private _totalAllocPoint;

    MetricToken private _metric;

    constructor(MetricToken metric) {
        _metric = metric;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DISTRIBUTOR_ROLE, msg.sender);
    }

    function addAllocationGroup(
        address newAddress,
        uint8 newShares,
        bool newAutoDistribute
    ) external onlyRole(DISTRIBUTOR_ROLE) {
        AllocationGroup memory group = AllocationGroup({
            groupAddress: newAddress,
            shares: newShares,
            autodistribute: newAutoDistribute,
            lastRewardBlock: block.number,
            rewardDebt: 0,
            accMETRICPerShare: 0
        });

        _allocations.push(group);
        _totalAllocPoint = _totalAllocPoint.add(group.shares);
    }

    function setLP(uint256 agIndex, uint8 shares) public onlyRole(DISTRIBUTOR_ROLE) {
        _totalAllocPoint = _totalAllocPoint.sub(_allocations[agIndex].shares).add(shares);
        _allocations[agIndex].shares = shares;
    }

    function removeAllocationGroup(uint256 agIndex) external onlyRole(DISTRIBUTOR_ROLE) {
        require(agIndex < _allocations.length);
        _totalAllocPoint = _totalAllocPoint.sub(_allocations[agIndex].shares);

        _allocations[agIndex] = _allocations[_allocations.length - 1];
        _allocations.pop();
    }

    function getAllocationGroups() public view returns (AllocationGroup[] memory) {
        return _allocations;
    }

    function getTotalAllocationPoints() public view returns (uint256) {
        return _totalAllocPoint;
    }

    function distributeAllocations(uint256 agIndex) public {
        AllocationGroup storage group = _allocations[agIndex];

        if (block.number <= group.lastRewardBlock) {
            return;
        }

        // TODO confirm budget is correct with assertions

        uint256 blocks = block.number.sub(group.lastRewardBlock);

        uint256 metricReward = blocks.mul(METRIC_PER_BLOCK).div(_totalAllocPoint);

        if (group.autodistribute) {
            _metric.transfer(group.groupAddress, metricReward);
        }

        group.accMETRICPerShare = group.accMETRICPerShare.add(metricReward.mul(ACC_METRIC_PRECISION));
        group.lastRewardBlock = block.number;
    }

    struct AllocationGroup {
        address groupAddress;
        uint8 shares;
        bool autodistribute;
        uint256 lastRewardBlock;
        uint256 rewardDebt; // Reward Debt is modelled after Sushi's MasterChefv2
        uint256 accMETRICPerShare;
    }
}
