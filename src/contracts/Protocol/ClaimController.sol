//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

// Interfaces
import "./interfaces/IClaimController.sol";

// Enums
import "./Enums/ClaimEnum.sol";

// Modifiers
import "./modifiers/OnlyAPI.sol";

contract ClaimController is Ownable, IClaimController, OnlyApi {
    /// @notice Keeps track of claim limits per question
    mapping(uint256 => uint256) public claimLimits;

    /// @notice maps answers to the question they belong to
    mapping(uint256 => mapping(address => Answer)) public answers;

    /// @notice maps all claimers to a question
    mapping(uint256 => address[]) public claims;

    //------------------------------------------------------ ERRORS

    /// @notice Throw if user tries to claim a question that is past its limit
    error ClaimLimitReached();

    /// @notice Throw if a analyst tries to answer a question that it has not claimed
    error NeedClaimToAnswer();

    /// @notice Throw if analyst tries to claim a question multiple times
    error AlreadyClaimed();

    //------------------------------------------------------ STRUCTS

    struct Answer {
        CLAIM_STATE state;
        address author;
        string answerURL;
        uint256 finalGrade;
        string scoringMetaDataURI; // store heuristics and such on ipfs
    }

    // ------------------------------------------------------ FUNCTIONS

    /**
     * @notice Initializes a question to receive claims
     * @param questionId The id of the question
     * @param claimLimit The limit for the amount of people that can claim the question
     */
    function initializeQuestion(uint256 questionId, uint256 claimLimit) public onlyApi {
        claimLimits[questionId] = claimLimit;
    }

    function claim(address user, uint256 questionId) public onlyApi {
        if (claims[questionId].length >= claimLimits[questionId]) revert ClaimLimitReached();
        if (answers[questionId][user].author == user) revert AlreadyClaimed();

        claims[questionId].push(user);
        Answer memory _answer = Answer({state: CLAIM_STATE.CLAIMED, author: user, answerURL: "", scoringMetaDataURI: "", finalGrade: 0});
        answers[questionId][user] = _answer;
    }

    function releaseClaim(address user, uint256 questionId) public onlyApi {}

    function answer(
        address user,
        uint256 questionId,
        string calldata answerURL
    ) public onlyOwner {
        if (answers[questionId][user].state != CLAIM_STATE.CLAIMED) revert NeedClaimToAnswer();
        answers[questionId][user].answerURL = answerURL;
    }

    function getClaims(uint256 questionId) public view returns (address[] memory _claims) {
        return claims[questionId];
    }

    function getClaimLimit(uint256 questionId) public view returns (uint256) {
        return claimLimits[questionId];
    }

    function getClaimDataForUser(uint256 questionId, address user) public view returns (Answer memory _answer) {
        return answers[questionId][user];
    }
}
