//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Question/IBountyQuestion.sol";

contract QuestionFactory is AccessControl {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    IBountyQuestion private _question;

    function createQuestion() public payable {}

    function upvoteQuestion() public payable {}

    function claimQuestion() public payable {}

    function setQuestionProxy(address newQuestion) public onlyRole(MANAGER_ROLE) {
        _question = IBountyQuestion(newQuestion);
    }
}
