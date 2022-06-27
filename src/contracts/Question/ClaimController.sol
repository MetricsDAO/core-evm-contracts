//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IClaimController.sol";

contract ClaimController is Ownable, IClaimController {
    mapping(uint256 => uint256) public claimLimits;
    mapping(uint256 => mapping(address => Answer)) public answers;
    mapping(uint256 => address[]) public claims;

    function initializeQuestion(uint256 questionId, uint256 claimLimit) public onlyOwner {
        claimLimits[questionId] = claimLimit;
    }

    error ClaimLimitReached();

    function claim(uint256 questionId) public onlyOwner {
        if (claims[questionId].length >= claimLimits[questionId]) revert ClaimLimitReached();

        claims[questionId].push(_msgSender());
        Answer memory _answer = Answer({state: STATE.CLAIMED, author: _msgSender(), url: "", finalGrade: 0});
        answers[questionId][_msgSender()] = _answer;
    }

    error NeedClaimToAnswer();

    function answer(uint256 questionId, string calldata answerURL) public onlyOwner {
        if (answers[questionId][_msgSender()].state != STATE.CLAIMED) revert NeedClaimToAnswer();
        answers[questionId][_msgSender()].url = answerURL;
    }

    //------------------------------------------------------ View Functions

    function getClaims(uint256 questionId) public view returns (address[] memory _claims) {
        return claims[questionId];
    }

    //------------------------------------------------------ Structs

    struct Answer {
        STATE state;
        address author;
        string url;
        // uint256 grade; //4 heuristics per question, multiple people review, and then aggregate is calculated
        // uint256 gradeOutOf;
        // TODO let's prototype a demo of this
        uint256 finalGrade;
        string scoringMetaDataURI; // store heuristics and such
    }

    enum STATE {
        UNINT,
        CLAIMED,
        ANSWERED
    }
}
