//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @custom:security-contact contracts@metricsdao.xyz
contract BountyQuestion is ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Burnable, AccessControl {
    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private _tokenIdCounter;
    mapping(uint256 => address) private _authors; // TODO if we want questions to be transferable, then owner != author
    mapping(uint256 => uint256) private _createdAt;
    mapping(uint256 => uint256) private _claimLimit;
    mapping(uint256 => string) private _metadata; // TODO standardize metadata format, including question copy
    mapping(uint256 => Vote[]) private _votes;
    mapping(uint256 => Claim[]) private _claims;
    mapping(uint256 => STATE) private _state;

    constructor() ERC721("MetricsDAO Question", "MDQ") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    // TODO people can submit garbage as metadata if they want
    function safeMint(address to, string memory uri) public onlyRole(MINTER_ROLE) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function wtf() private {
        safeMint(_msgSender(), "");
    }

    //------------------------------------------------------ Structs

    struct Vote {
        address _voter;
        uint256 _amount;
        uint256 _weightedVote;
    }

    struct Claim {
        address _claimer;
        Answer _answer;
    }

    struct Answer {
        address _author;
        string _url;
        // TODO grades?
        uint256 _finalGrade;
    }

    enum STATE {
        DRAFT,
        PUBLISHED,
        IN_GRADING,
        COMPLETED,
        CANCELLED
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

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
