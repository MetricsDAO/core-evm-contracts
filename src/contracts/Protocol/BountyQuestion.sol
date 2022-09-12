//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// Interfaces
import "./interfaces/IQuestionAPI.sol";

// Modifiers
import "./modifiers/OnlyAPI.sol";
import "./modifiers/OnlyStateController.sol";

// Structs
import "./Structs/QuestionData.sol";

/// @custom:security-contact contracts@metricsdao.xyz
contract BountyQuestion is Ownable, OnlyApi, OnlyStateController {
    using Counters for Counters.Counter;

    Counters.Counter private _questionIdCounter;

    // This maps the author to the list of question IDs they have created
    mapping(address => uint256[]) public authors;

    mapping(uint256 => QuestionData) public questionData;

    constructor() {
        _questionIdCounter.increment();
    }

    function mintQuestion(address author, string calldata uri) public onlyApi returns (uint256) {
        uint256 questionId = _questionIdCounter.current();
        _questionIdCounter.increment();

        questionData[questionId].author = author;
        questionData[questionId].questionId = questionId;
        questionData[questionId].uri = uri;

        authors[author].push(questionId);
        return questionId;
    }

    function updateState(uint256 questionId, STATE newState) public onlyStateController {
        QuestionData storage question = questionData[questionId];
        question.questionState = newState;
    }

    function updateVotes(uint256 questionId, uint256 newVotes) public onlyStateController {
        QuestionData storage question = questionData[questionId];
        question.totalVotes = newVotes;
    }

    function getAuthor(address user) public view returns (QuestionData[] memory) {
        uint256[] memory created = authors[user];

        QuestionData[] memory ret = new QuestionData[](created.length);

        for (uint256 i = 0; i < created.length; i++) {
            ret[i] = questionData[created[i]];
        }
        return ret;
    }

    function getAuthorOfQuestion(uint256 questionId) public view returns (address) {
        return questionData[questionId].author;
    }

    function getMostRecentQuestion() public view returns (uint256) {
        return _questionIdCounter.current() - 1;
    }

    function getQuestionData(uint256 questionId) public view returns (QuestionData memory) {
        return questionData[questionId];
    }
}
