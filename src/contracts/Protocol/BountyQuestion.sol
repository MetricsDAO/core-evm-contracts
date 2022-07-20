//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./modifiers/OnlyAPI.sol";

// Question -> Challenge is many -> one mapping
// auto-transition from question -> challenge on:
//   Voting threshold -> do we want manual approval? -> yes
//   Admin approval (Messari group wants to write their own challenges)
// TODO ability for author to unlock and "kill" their question -> reimburse voters

// philosphy -> start out gated and the protocol can evolve in the same way the dao does

/// @custom:security-contact contracts@metricsdao.xyz
contract BountyQuestion is Ownable, OnlyApi {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    mapping(uint256 => string) public questionMetadata;
    mapping(address => QuestionData[]) public authors;

    constructor() {
        _tokenIdCounter.increment();
    }

    function createQuestion(address author, string calldata uri) public onlyApi returns (uint256) {
        // Checks
        // Effects
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        creators[tokenId].push(author);
        questionMetadata[tokenId] = uri;

        // Interactions

        return tokenId;
    }
}
