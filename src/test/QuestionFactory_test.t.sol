// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "@contracts/MetricToken.sol";

contract VestingContract {
    constructor() public payable {}
}

contract MetricTokenTest is DSTest {
    MetricToken _metricToken;
    VestingContract _vestingContract;

    function setUp() public {
        _vestingContract = new VestingContract();
        _metricToken = new MetricToken(address(_vestingContract));
    }

    function testInitialMint() public {
        assertTrue(_metricToken.balanceOf(address(_vestingContract)) == 1000000000 * 10**18);
    }
}
