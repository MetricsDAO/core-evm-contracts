//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../MetricToken.sol";
import "./Vault.sol";

// Interfaces
import "./interfaces/IActionCostController.sol";

// Modifiers
import "./modifiers/OnlyAPI.sol";

contract ActionCostController is Ownable, OnlyApi, IActionCostController {
    IERC20 private metric;
    Vault private vault;

    uint256 public createCost;
    uint256 public voteCost;

    constructor(address _metric, address _vault) {
        metric = IERC20(_metric);
        vault = Vault(_vault);
        createCost = 1e18;
        voteCost = 1e18;
    }

    /**
    * @notice Makes a user pay for creating a question. 
            We transfer the funds from the user executing the function to 
            the contract.
    * @param _user The address of the user who wants to pay for creating a question.
    */
    function payForCreateQuestion(address _user, uint256 _questionId) external onlyApi {
        // Checks
        // Effects
        // Interactions
        vault.lockMetric(_user, createCost, _questionId, 0);
    }

    /**
    * @notice Makes a user pay for voting on a question. 
            We transfer the funds from the user executing the function to 
            the contract.
    * @param _user The address of the user who wants to pay for voting on a question.
    */
    function payForVoting(address _user) external onlyApi {
        // Checks
        // Effects
        // Interactions
    }

    // ------------------------------- Getter
    // ------------------------------- Admin

    /**
     * @notice Changes the cost of creating a question
     * @param _cost The new cost of creating a question
     */
    function setCreateCost(uint256 _cost) external onlyOwner {
        createCost = _cost;
    }

    /**
     * @notice Changes the cost of voting for a question
     * @param _cost The new cost of voting for a question
     */
    function setVoteCost(uint256 _cost) external onlyOwner {
        voteCost = _cost;
    }

    function setMetric(address _metric) public onlyOwner {
        metric = IERC20(_metric);
    }
}
