//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IActionCostController.sol";
import "./OnlyApi.sol";
import "../MetricToken.sol";

// TODO we probably want a CostController or something to ensure user locks enough metric
// ^^ price per action, each one is editable
// Basically the QuestionAPI will request the price from this controler and ensure
contract ActionCostController is Ownable, OnlyApi, IActionCostController {
    IERC20 private metric;

    uint256 public createCost;

    mapping(address => uint256) lockedPerUser;

    constructor(address _metric) {
        metric = IERC20(_metric);
        createCost = 1e18;
    }

    /**
    * @notice Makes a user pay for creating a question. 
            We transfer the funds from the user executing the function to 
            the contract.
    * @param _user The address of the user who wants to pay for creating a question.
    */
    function payForCreateQuestion(address _user) external onlyApi {
        // TODO where do we want to store locked metric?
        lockedPerUser[_user] += createCost;
        // Why safeERC20?
        SafeERC20.safeTransferFrom(metric, _user, address(this), createCost);
    }

    // ------------------------------- Getter
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
