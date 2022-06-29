// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract xMETRIC is ERC20("xMETRIC", "xMETRIC"), Ownable {
    constructor(uint256 initialSupply) {
        _mint(msg.sender, initialSupply);
    }

    //------------------------------------------------------Overrides
    function transfer(address to, uint256 amount) public override transactor returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override transactor returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    //------------------------------------------------------Setters
    function addTransactor(address _transactor) public onlyOwner {
        canTransact[_transactor] = true;
    }

    //------------------------------------------------------Getters

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
