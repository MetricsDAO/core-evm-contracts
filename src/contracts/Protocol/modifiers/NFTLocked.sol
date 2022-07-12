// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";

abstract contract NFTLocked is Ownable {
    mapping(bytes32 => address) private _nfts;

    function addHolderRole(bytes32 role, address nft) public onlyOwner {
        _nfts[role] = nft;
    }

    modifier onlyHolder(bytes32 role) {
        _checkRole(role);
        _;
    }

    error DoesNotHold();

    function _checkRole(bytes32 role) internal view virtual {
        if (IERC721(_nfts[role]).balanceOf(_msgSender()) == 0) revert DoesNotHold();
    }
}
