//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./modifiers/OnlyAPI.sol";

/// @custom:security-contact contracts@metricsdao.xyz
contract BountyQuestion is Ownable, OnlyApi {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    // This maps the author to the list of token IDs they have created
    mapping(address => uint256[]) public authors;

    // This maps the token ID to the question data
    mapping(uint256 => QuestionData) public questions;

    constructor() {
        _tokenIdCounter.increment();
    }

    function createQuestion(address author, string calldata uri) public onlyApi returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        questions[tokenId] = QuestionData({tokenId: tokenId, url: uri});
        // QuestionData memory _question = QuestionData({tokenId: tokenId, url: uri});
        authors[author].push(tokenId);
        return tokenId;
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
