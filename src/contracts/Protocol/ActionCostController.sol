//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IActionCostController.sol";
import "./modifiers/OnlyAPI.sol";
import "../MetricToken.sol";
import "./Vault.sol";

// TODO we probably want a CostController or something to ensure user locks enough metric
// ^^ price per action, each one is editable
// Basically the QuestionAPI will request the price from this controler and ensure
contract ActionCostController is Ownable, OnlyApi, IActionCostController {
    IERC20 private metric;
    Vault private vault;
    uint256 public createCost;

    mapping(address => uint256) lockedPerUser;

    // TODO remove constructor arguments -- instead setters?
    constructor(address _metric, address _vault) {
        metric = IERC20(_metric);
        vault = Vault(_vault);
        createCost = 1e18;
    }

    /**
    * @notice Makes a user pay for creating a question. 
            We transfer the funds from the user executing the function to 
            the contract.
    * @param _user The address of the user who wants to pay for creating a question.
    */
    function payForCreateQuestion(address _user, uint256 _questionId) external onlyApi {
        // Do we want this?
        lockedPerUser[_user] += createCost;
        // Why safeERC20?
        vault.lockMetric(_user, createCost, _questionId);
    }

    // ------------------------------- Getter
    // Do we want this?
    function getLockedPerUser(address _user) public view returns (uint256) {
        return lockedPerUser[_user];
    }

    // ------------------------------- Admin

    /**
     * @notice Changes the cost of creating a question
     * @param _cost The new cost of creating a question
     */
    function setCreateCost(uint256 _cost) external onlyOwner {
        createCost = _cost;
    }

    function setMetric(address _metric) public onlyOwner {
        metric = IERC20(_metric);
    }
}
