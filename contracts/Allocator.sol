//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./MetricToken.sol";

contract Allocator is AccessControl {
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

    AllocationGroup[] private _allocations;
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
    }

    function getAllocationGroups() public view returns (AllocationGroup[] memory) {
        return _allocations;
    }

    function removeAllocationGroup(uint8 index) external onlyRole(DISTRIBUTOR_ROLE) {
        require(index < _allocations.length);
        _allocations[index] = _allocations[_allocations.length - 1];
        _allocations.pop();
    }

    function getTotalAllocatedShares() public view returns (uint8) {
        uint8 total = 0;
        uint256 count = _allocations.length;
        for (uint8 i = 0; i < count; i++) {
            total += _allocations[i]._shares;
        }
        return total;
    }

    struct AllocationGroup {
        address _address;
        uint8 _shares;
        bool _autodistribute;
        uint256 _lastRewardBlock;
    }
}
