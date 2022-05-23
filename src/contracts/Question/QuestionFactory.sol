//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./BountyQuestion.sol";
import "./interfaces/IClaimController.sol";
import "./interfaces/IQuestionStateController.sol";

contract QuestionFactory is Ownable {
    BountyQuestion private _question;
    IQuestionStateController private _questionStateController;
    IClaimController private _claimController;

    constructor(
        address bountyQuestion,
        address questionStateController,
        address claimController
    ) {
        _question = BountyQuestion(bountyQuestion);
        _questionStateController = IQuestionStateController(questionStateController);
        _claimController = IClaimController(claimController);
    }

    function createQuestion(string memory uri) public payable {
        uint256 newTokenId = _question.safeMint(_msgSender(), uri);
        _questionStateController.initializeQuestion(newTokenId);
    }

    function upvoteQuestion() public payable {}

    function claimQuestion() public payable {}

    function setQuestionProxy(address newQuestion) public onlyOwner {
        _question = BountyQuestion(newQuestion);
    }

    function setQuestionStateController(address newQuestion) public onlyOwner {
        _questionStateController = IQuestionStateController(newQuestion);
    }

    function setClaimController(address newQuestion) public onlyOwner {
        _claimController = IClaimController(newQuestion);
    }
}
