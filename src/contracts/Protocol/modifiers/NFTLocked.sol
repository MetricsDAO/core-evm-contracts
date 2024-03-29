// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

// Interfaces
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";

abstract contract NFTLocked is Ownable {
    bytes32 public constant PROGRAM_MANAGER_ROLE = keccak256("PROGRAM_MANAGER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

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
