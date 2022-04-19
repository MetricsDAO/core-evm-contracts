// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "../contracts/Allocator.sol";
import "@contracts/MetricToken.sol";

contract ContractTest is DSTest {
    address _metricTokenAddress;

    function setUp() public {
      MetricToken metricToken = new MetricToken();
      _metricTokenAddress = address(metricToken);
      emit log_named_address("Token", _metricTokenAddress);
    }

    function testDeployedToken() public {
        assertTrue(_metricTokenAddress == address(MetricToken(_metricTokenAddress)));
    }
}
