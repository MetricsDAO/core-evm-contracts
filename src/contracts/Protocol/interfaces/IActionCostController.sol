// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IActionCostController {
    function payForCreateQuestion(address _user) external;

    function setCreateCost(uint256 _cost) external;
}
