// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@contracts/MetricToken.sol";

/// @custom:security-contact contracts@metricsdao.com
contract MetricFaucet {
    MetricToken public _metricToken;
    
    uint public requestIncrement = 1000000000 * 10**18;

    constructor(address metricTokenAddress) {
        _metricToken = MetricToken(metricTokenAddress);
    }

    function requestTokens() public {
        _metricToken.transfer(msg.sender, requestIncrement);
    }
}
