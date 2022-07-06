//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IActionCostController.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../MetricToken.sol";

// TODO we probably want a CostController or something to ensure user locks enough metric
// ^^ price per action, each one is editable
// Basically the QuestionAPI will request the price from this controler and ensure
contract ActionCostController is Ownable, IActionCostController {
    MetricToken private metric;

    address public questionApi;
    uint256 public createCost;

    mapping(address => uint256) lockedPerUser;

    constructor(address _metric) {
        metric = MetricToken(_metric);
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
        lockedPerUser[msg.sender] += createCost;
        // Why safeERC20?
        SafeERC20.safeTransferFrom(metric, _user, address(this), createCost);
    }

    /**
     * @notice Sets the cost of creating a question
     * @param _cost The cost of creating a question
     */
    function setCreateCost(uint256 _cost) external onlyApi {
        createCost = _cost;
    }

    /**
     * @notice Sets the address of the question API.
     * @param _questionApi The address of the question API.
     */
    function setQuestionApi(address _questionApi) public onlyOwner {
        questionApi = _questionApi;
    }

    // ------------------------------- Modifier
    modifier onlyApi() {
        if (msg.sender != questionApi) revert NotTheApi();
        _;
    }
    // ------------------------------- Errors
    error NotTheApi();
}
