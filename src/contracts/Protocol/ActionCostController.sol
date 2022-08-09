//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../MetricToken.sol";
import "./Vault.sol";

// Interfaces
import "./interfaces/IActionCostController.sol";

// Enums
import "./Enums/VaultEnum.sol";
import "./Enums/ActionEnum.sol";

// Modifiers
import "./modifiers/OnlyAPI.sol";

contract ActionCostController is Ownable, OnlyApi, IActionCostController {
    IERC20 private metric;
    Vault private vault;

    mapping(ACTION => uint256) public actionCost;
    mapping(ACTION => STAGE) public actionStage;

    constructor(address _metric, address _vault) {
        metric = IERC20(_metric);
        vault = Vault(_vault);

        actionCost[ACTION.CREATE] = 1e18;
        actionCost[ACTION.VOTE] = 1e18;

        actionStage[ACTION.CREATE] = STAGE.CREATE_AND_VOTE;
        actionStage[ACTION.VOTE] = STAGE.CREATE_AND_VOTE;
    }

    function payForAction(
        address _user,
        uint256 questionId,
        ACTION action
    ) external onlyApi {
        vault.lockMetric(_user, actionCost[action], questionId, actionStage[action]);
    }

    // ------------------------------- Getter
    // ------------------------------- Admin

    /**
     * @notice Changes the cost of creating a question
     * @param cost The new cost of creating a question
     */
    function setActionCost(ACTION action, uint256 cost) external onlyOwner {
        actionCost[action] = cost;
    }

    function setMetric(address _metric) public onlyOwner {
        metric = IERC20(_metric);
    }
}
