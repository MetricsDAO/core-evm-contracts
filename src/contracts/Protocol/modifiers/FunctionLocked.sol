// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract FunctionLocked is Ownable {
    bool isLocked;

    error FunctionIsLocked();

    function toggleLock() public onlyOwner {
        isLocked = !isLocked;
    }

    modifier functionLocked() {
        if (isLocked) revert FunctionIsLocked();
        _;
    }
}
