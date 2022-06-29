//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "./TopChef.sol";

contract InvestorChef is TopChef {
    constructor(address metricTokenAddress) TopChef(metricTokenAddress) {}
}
