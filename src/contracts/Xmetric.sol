// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

contract Xmetric is ERC20("xMETRIC", "xMETRIC"), ERC20Pausable, Ownable {
    constructor() {
        setTransactor(msg.sender, true);
    }

    //------------------------------------------------------Overrides

    function transfer(address to, uint256 amount) public override transactor returns (bool) {
        _mint(to, amount);
        return true;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override transactor returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _mint(to, amount);
        _burn(from, amount);
        return true;
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function burnFrom(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }

    //------------------------------------------------------Setters

    function setTransactor(address _transactor, bool _isAllowed) public onlyOwner {
        canTransact[_transactor] = _isAllowed;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unPause() public onlyOwner {
        _unpause();
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
