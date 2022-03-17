// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @custom:security-contact metric@gmail.com
contract MetricToken is ERC20 {
    constructor() ERC20("METRIC", "MTR") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}
