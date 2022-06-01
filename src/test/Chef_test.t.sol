// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "@contracts/TopChef.sol";
import "@contracts/MetricToken.sol";

contract TokenUser {
    MetricToken _metric;
    TopChef _allocator;

    constructor(MetricToken token_, TopChef allocator) {
        _metric = token_;
        _allocator = allocator;
    }

    function tryToggleRewards() public {
        _allocator.toggleRewards(true);
    }
}

contract VestingContract {
    constructor() public payable {}
}

contract ContractTest is DSTest {
    address _metricTokenAddress;
    TopChef allocator;
    TokenUser userOne;

    function setUp() public {
        VestingContract _vestingContract;
        MetricToken metricToken = new MetricToken(address(_vestingContract));
        _metricTokenAddress = address(metricToken);
        allocator = new TopChef(address(metricToken));
        userOne = new TokenUser(metricToken, allocator);
    }

    function testDeployedToken() public {
        assertTrue(_metricTokenAddress == address(MetricToken(_metricTokenAddress)));
    }

    function testRoleAssignment() public {
        assertTrue(allocator.owner() == address(this));
    }

    function testFailRoleAssignment() public {
        assertTrue(allocator.owner() == address(userOne));
    }

    function testFailToggle() public {
        userOne.tryToggleRewards();
    }

    function testToggleRewards() public {
        allocator.toggleRewards(true);
    }

    function testChefInitialState() public {
        allocator.getAllocationGroups();
    }
}
