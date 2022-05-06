// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "@contracts/MetricToken.sol";
import "@contracts/MetricFaucet.sol";

contract TokenUser {
  MetricToken _metric;
  MetricFaucet _faucet;
    constructor(MetricToken token, MetricFaucet faucet) {
        _metric = token;
        _faucet = faucet;
    }

    function tryFaucetRequest() public {
        _faucet.requestTokens();
    }
}

contract FaucetTest is DSTest {
    MetricToken _metricToken;
    MetricFaucet _faucet;
    TokenUser _userOne;

    function setUp() public {
        _metricToken = new MetricToken(address(this));
        _faucet = new MetricFaucet(address(_metricToken));
        _userOne = new TokenUser(_metricToken, _faucet);
        _metricToken.transfer(address(_faucet), 1000000000 * 10**18); 
    }

    function testFaucetRequest() public {
        uint balanceBefore = _metricToken.balanceOf(address(_userOne));
        _userOne.tryFaucetRequest();
        uint balanceAfter = _metricToken.balanceOf(address(_userOne));
        assertLt(balanceBefore, balanceAfter);
    }
}
