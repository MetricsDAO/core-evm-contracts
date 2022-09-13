//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

import {IQuestionAPI} from "../interfaces/IQuestionAPI.sol";

contract OnlyStateController is Ownable {
    address public stateController;
    IQuestionAPI public questionAPI;

    // ------------------------------- Setter
    function updateStateController() public {
        stateController = questionAPI.getQuestionStateController();
    }

    function setQuestionApiSC(address _questionAPI) public onlyOwner {
        questionAPI = IQuestionAPI(_questionAPI);
    }

    // ------------------------ Modifiers
    modifier onlyStateController() {
        if (_msgSender() != stateController) revert NotTheStateController();
        _;
    }

    // ------------------------ Errors
    error NotTheStateController();
}
