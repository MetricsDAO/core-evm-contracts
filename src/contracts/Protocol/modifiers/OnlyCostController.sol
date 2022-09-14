//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

import {IQuestionAPI} from "../interfaces/IQuestionAPI.sol";

contract OnlyCostController is Ownable {
    address public costController;
    IQuestionAPI public questionAPI;

    // ------------------------------- Setter
    function updateCostController() public {
        costController = questionAPI.getCostController();
    }

    function setQuestionApiCC(address _questionAPI) public onlyOwner {
        questionAPI = IQuestionAPI(_questionAPI);
    }

    // ------------------------ Modifiers
    modifier onlyCostController() {
        if (_msgSender() != costController) revert NotTheCostController();
        _;
    }

    // ------------------------ Errors
    error NotTheCostController();
}
