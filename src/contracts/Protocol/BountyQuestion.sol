//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./modifiers/OnlyAPI.sol";

// TODO remove ERC721 stuff here
// TODO introduce a Challenge data model
// Question -> Challenge is many -> one mapping
// auto-transition from question -> challenge on:
//   Voting threshold -> do we want manual approval? -> yes
//   Admin approval (Messari group wants to write their own challenges)
// TODO ability for author to unlock and "kill" their question -> reimburse voters

// philosphy -> start out gated and the protocol can evolve in the same way the dao does

/// @custom:security-contact contracts@metricsdao.xyz
contract BountyQuestion is ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Burnable, Ownable, OnlyApi {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    // mapping(uint256 => address) private _authors; // TODO if we want questions to be transferable, then owner != author
    // uint256[] public tokenIds;
    mapping(address => uint256[]) public _authors;
    mapping(uint256 => uint256) private _createdAt;

    constructor() ERC721("MetricsDAO Question", "MDQ") {}

    // working standard metadata format:  Title, Description, Program
    function safeMint(address to, string calldata uri) public onlyApi returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        _authors[to].push(tokenId);
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

    function getAuthor(address user) public view returns (uint256[] memory) {
        return _authors[user];
    }
}
