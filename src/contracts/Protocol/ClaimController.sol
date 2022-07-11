//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IClaimController.sol";
import "./OnlyApi.sol";

contract ClaimController is Ownable, IClaimController, OnlyApi {
    mapping(uint256 => uint256) public claimLimits;
    mapping(uint256 => mapping(address => Answer)) public answers;
    mapping(uint256 => address[]) public claims;

    /**
     * @notice Initializes a question to receive claims
     * @param questionId The id of the question
     * @param claimLimit The limit for the amount of people that can claim the question
     */
    function initializeQuestion(uint256 questionId, uint256 claimLimit) public onlyApi {
        claimLimits[questionId] = claimLimit;
    }

    function claim(uint256 questionId) public onlyOwner {
        if (claims[questionId].length >= claimLimits[questionId]) revert ClaimLimitReached();

        claims[questionId].push(_msgSender());
        Answer memory _answer = Answer({state: STATE.CLAIMED, author: _msgSender(), answerURL: "", scoringMetaDataURI: "", finalGrade: 0});
        answers[questionId][_msgSender()] = _answer;
    }

    function answer(uint256 questionId, string calldata answerURL) public onlyOwner {
        if (answers[questionId][_msgSender()].state != STATE.CLAIMED) revert NeedClaimToAnswer();
        answers[questionId][_msgSender()].answerURL = answerURL;
    }

    //------------------------------------------------------ View Functions

    function getClaims(uint256 questionId) public view returns (address[] memory _claims) {
        return claims[questionId];
    }

    function getClaimLimit(uint256 questionId) public view returns (uint256) {
        return claimLimits[questionId];
    }

    //------------------------------------------------------ Errors
    error ClaimLimitReached();
    error NeedClaimToAnswer();

    //------------------------------------------------------ Structs

    struct Answer {
        STATE state;
        address author;
        string answerURL;
        // uint256 grade; //4 heuristics per question, multiple people review, and then aggregate is calculated
        // TODO let's prototype a demo of this
        uint256 finalGrade;
        string scoringMetaDataURI; // store heuristics and such on ipfs
    }

    enum STATE {
        UNINT,
        CLAIMED,
        ANSWERED
    }
}
