// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../Enums/ActionEnum.sol";

interface IActionCostController {
    function setActionCost(ACTION action, uint256 cost) external;

    function payForAction(
        address _user,
        uint256 questionId,
        ACTION action
    ) external;

    function burnForAction(address _user, ACTION action) external;
}
