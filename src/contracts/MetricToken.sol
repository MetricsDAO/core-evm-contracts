// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @custom:security-contact contracts@metricsdao.com
contract MetricToken is ERC20 {
    constructor() ERC20("METRIC", "METRIC") {
        _mint(msg.sender, 1000000000 * 10**decimals());
        //TODO don't mint to _msgSender, mint to vesting contract
    }
}
