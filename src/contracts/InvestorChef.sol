//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./TopChef.sol";

contract InvestorChef is TopChef {
    constructor(address metricTokenAddress) TopChef(metricTokenAddress) {}
}
