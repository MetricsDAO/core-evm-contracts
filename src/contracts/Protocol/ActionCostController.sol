//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IActionCostController} from "./interfaces/IActionCostController.sol";
import {IVault} from "./interfaces/IVault.sol";

// Enums
import {STAGE} from "./Enums/VaultEnum.sol";
import {ACTION} from "./Enums/ActionEnum.sol";

// Modifiers
import "./modifiers/OnlyAPI.sol";

contract ActionCostController is Ownable, OnlyApi, IActionCostController {
    IVault private _vault;

    mapping(ACTION => uint256) public actionCost;
    mapping(ACTION => STAGE) public actionStage;

    //------------------------------------------------------ CONSTRUCTOR
    constructor(address vault) {
        _vault = IVault(vault);

        actionCost[ACTION.CREATE] = 1e18;
        actionCost[ACTION.VOTE] = 1e18;
        actionCost[ACTION.CLAIM] = 1e18;
        actionCost[ACTION.CHALLENGE_BURN] = 1000e18;
        actionCost[ACTION.CHALLENGE_CREATE];
        actionCost[ACTION.PUBLISH];

        actionStage[ACTION.CREATE] = STAGE.CREATE_AND_VOTE;
        actionStage[ACTION.VOTE] = STAGE.CREATE_AND_VOTE;
        actionStage[ACTION.CLAIM] = STAGE.CLAIM_AND_ANSWER;
        actionStage[ACTION.CHALLENGE_CREATE] = STAGE.REVIEW;
        actionStage[ACTION.PUBLISH] = STAGE.REVIEW;
    }

    // ------------------------------------------------------ FUNCTIONS

    function payForAction(
        address _user,
        uint256 questionId,
        ACTION action
    ) external onlyApi {
        _vault.lockMetric(_user, actionCost[action], questionId, actionStage[action]);
    }

    function burnForAction(address _user, ACTION action) external onlyApi {
        _vault.burnMetric(_user, actionCost[action]);
    }

    // ------------------------------------------------------ VIEW FUNCTIONS

    function getActionCost(ACTION action) public view returns (uint256) {
        return actionCost[action];
    }

    //------------------------------------------------------ OWNER FUNCTIONS

    /**
     * @notice Changes the cost of creating a question
     * @param cost The new cost of creating a question
     */
    function setActionCost(ACTION action, uint256 cost) external onlyOwner {
        actionCost[action] = cost;
    }
}
