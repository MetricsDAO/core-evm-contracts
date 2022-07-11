//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// TODO remove ERC721 stuff here
// TODO introduce a Challenge data model
// Question -> Challenge is many -> one mapping
// auto-transition from question -> challenge on:
//   Voting threshold -> do we want manual approval? -> yes
//   Admin approval (Messari group wants to write their own challenges)
// TODO ability for author to unlock and "kill" their question -> reimburse voters

// authorization philosphy -> start out gated and the protocol can evolve in the same way the dao does

// TODO right now this is identical to a question - but this is an "approved" question
// Basically, when a question is Voted enough Or manually approved, it becomes a `Challenge` and the rest of the API uses a Challenge.

/// @custom:security-contact contracts@metricsdao.xyz
contract BountyChallenge is ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Burnable, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    mapping(uint256 => address) private _authors; // TODO if we want questions to be transferable, then owner != author
    mapping(uint256 => uint256) private _createdAt;

    constructor() ERC721("MetricsDAO Question", "MDQ") {}

    // working standard metadata format:  Title, Description, Program
    function safeMint(address to, string memory uri) public onlyOwner returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        return tokenId;
    }

    //------------------------------------------------------ Solidity Overrides

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
