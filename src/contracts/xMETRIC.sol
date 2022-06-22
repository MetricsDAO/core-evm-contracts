// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @notice We use solmate as it is more gas efficient thab OZ
/// @notice https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol
/// @notice  https://github.com/Rari-Capital/solmate/blob/main/src/auth/Owned.sol

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/owned.sol";

contract xMETRIC is ERC20("xMETRIC", "xMETRIC", 18), Owned {
    constructor(address _owner, uint256 initialSupply) Owned(_owner) {
        _mint(msg.sender, initialSupply);
    }

    //------------------------------------------------------Overrides
    function transfer(address to, uint256 amount)
        public
        override
        transactor
        returns (bool)
    {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override transactor returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max)
            allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    //------------------------------------------------------Setters
    function addTransactor(address _transactor) public onlyOwner {
        canTransact[_transactor] = true;
    }

    //------------------------------------------------------Getters
    function getOwner() public view returns (address) {
        return owner;
    }

    function isTransactor(address _addr) public view returns (bool) {
        return canTransact[_addr];
    }

    //------------------------------------------------------Support Functions
    mapping(address => bool) public canTransact;

    error AddressCannotTransact();

    modifier transactor() {
        // Check if msg.sender is allowed to transact
        if (canTransact[msg.sender] != true) revert AddressCannotTransact();
        _;
    }
}
