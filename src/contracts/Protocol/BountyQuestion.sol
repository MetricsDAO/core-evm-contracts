//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./modifiers/OnlyAPI.sol";

/// @custom:security-contact contracts@metricsdao.xyz
contract BountyQuestion is Ownable, OnlyApi {
    using Counters for Counters.Counter;

    Counters.Counter private _questionIdCounter;

    // This maps the author to the list of question IDs they have created
    mapping(address => uint256[]) public authors;

    // This maps the question ID to the question data
    mapping(uint256 => QuestionData) public questions;

    constructor() {
        _questionIdCounter.increment();
    }

    function mintQuestion(address author, string calldata uri) public onlyApi returns (uint256) {
        uint256 questionId = _questionIdCounter.current();
        _questionIdCounter.increment();

        questions[questionId] = QuestionData({tokenId: questionId, url: uri});
        authors[author].push(questionId);
        return questionId;
    }

    function getAuthor(address user) public view returns (QuestionData[] memory) {
        uint256[] memory created = authors[user];

        QuestionData[] memory ret = new QuestionData[](created.length);
        for (uint256 i = 0; i < created.length; i++) {
            ret[i] = questions[created[i]];
        }
        return ret;
    }

    struct QuestionData {
        uint256 tokenId;
        string url;
    }
}
