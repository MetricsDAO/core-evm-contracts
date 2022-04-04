//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./MetricToken.sol";

contract Allocator is AccessControl {
    using SafeMath for uint256;

    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

    uint256 private MOONDUST_PER_BLOCK = 4 * 10**18;
    uint256 private constant ACC_DUST_PRECISION = 1e12;

    AllocationGroup[] private _allocations;
    uint256 private totalAllocPoint;

    MetricToken private _metric;

    constructor(MetricToken metric) {
        _metric = metric;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DISTRIBUTOR_ROLE, msg.sender);
    }

    function addAllocationGroup(
        address toAdd,
        uint8 shares,
        bool distribution
    ) external onlyRole(DISTRIBUTOR_ROLE) {
        AllocationGroup memory group = AllocationGroup(toAdd, shares, distribution, block.number);
        _allocations.push(group);
        totalAllocPoint = totalAllocPoint.add(group.allocPoint);
    }

    function getAllocationGroups() public view returns (AllocationGroup[] memory) {
        return _allocations;
    }

    function removeAllocationGroup(uint8 index) external onlyRole(DISTRIBUTOR_ROLE) {
        require(index < _allocations.length);
        totalAllocPoint = totalAllocPoint.sub(_allocations[index]);

        _allocations[index] = _allocations[_allocations.length - 1];
        _allocations.pop();
    }

    function getTotalAllocationPoints() public view returns (uint256) {
        return totalAllocPoint;
    }

    function updateAllocations(uint256 _agIndex) public {
        AllocationGroup storage group = _allocations[_agIndex];

        if (block.number <= group._lastRewardBlock) {
            return;
        }

        // TODO confirm budget is correct with assertions

        uint256 blocks = block.number.sub(group.lastRewardBlock);

        uint256 eggReward = blocks.mul(MOONDUST_PER_BLOCK).div(totalAllocPoint);

        _metric.transfer(group._address, eggReward);

        group.accMoonPerShare = group.accMoonPerShare.add(eggReward.mul(ACC_DUST_PRECISION);
        group.lastRewardBlock = block.number;
    }

    struct AllocationGroup {
        address _address;
        uint8 _shares;
        bool _autodistribute;
        uint256 _lastRewardBlock;
        uint256 rewardDebt; // Reward Debt is modelled after Sushi's MasterChefv2
        uint256 accMoonPerShare;
    }
}
