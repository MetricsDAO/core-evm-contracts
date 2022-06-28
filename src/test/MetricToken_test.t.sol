// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "@contracts/MetricToken.sol";
import "hardhat/console.sol";

contract VestingContract {
    constructor() public payable {}
}

contract MetricTokenTest is DSTest {
    MetricToken _metricToken;
    VestingContract _vestingContract;

    function setUp() public {
        _vestingContract = new VestingContract();
        console.log("_vestingContract.address: %s ", address(_vestingContract));
        _metricToken = new MetricToken();
    }

    function testInitialMint() public {
        assertTrue(_metricToken.balanceOf(msg.sender) == 1000000000 * 10**18);
    }
}
