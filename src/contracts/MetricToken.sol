// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @custom:security-contact contracts@metricsdao.com
contract MetricToken is ERC20 {
    constructor(address _vestingContractAddress) ERC20("METRIC", "METRIC") {
        _mint(_vestingContractAddress, 1000000000 * 10**decimals());
    }
}
