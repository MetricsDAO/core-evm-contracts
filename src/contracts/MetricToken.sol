// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @custom:security-contact contracts@metricsdao.com
contract MetricToken is ERC20 {
    constructor() ERC20("METRIC", "METRIC") {
        _mint(_msgSender(), 1000000000 * 10**decimals());
    }
}
