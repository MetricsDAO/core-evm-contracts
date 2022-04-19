// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "@contracts/Allocator.sol";
import "@contracts/MetricToken.sol";



contract TokenUser {
  MetricToken _metric;
  Allocator _allocator;
    constructor(MetricToken token_, Allocator allocator) {
        _metric = token_;
        _allocator = allocator;
    }

    function tryToggleRewards() public {
        _allocator.toggleRewards(true);
    }
}

contract ContractTest is DSTest {
    address _metricTokenAddress;
    Allocator allocator;
    TokenUser userOne;

    function setUp() public {
      MetricToken metricToken = new MetricToken();
      _metricTokenAddress = address(metricToken);
      allocator = new Allocator(metricToken);
      userOne = new TokenUser(metricToken, allocator);
    }

    function testDeployedToken() public {
        assertTrue(_metricTokenAddress == address(MetricToken(_metricTokenAddress)));
    }

    function testRoleAssignment() public {
        assertTrue(allocator.hasRole(keccak256("ALLOCATION_ROLE"), address(this)));
    }

    function testFailRoleAssignment() public {
        assertTrue(allocator.hasRole(keccak256("ALLOCATION_ROLE"), address(userOne)));
    }

    function testFailToggle() public {
      userOne.tryToggleRewards();
    }

    function testToggleRewards() public {
      allocator.toggleRewards(true);
    }
}
