// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract MetricToken is ERC20, ERC20Burnable, ERC20Snapshot, AccessControl, ERC20Permit, ERC20Votes {
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    bool advisorMode = true;

    constructor() ERC20("Metric Token", "METRIC") ERC20Permit("Metric Token") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SNAPSHOT_ROLE, msg.sender);
        _mint(msg.sender, 1000000000 * 10 ** decimals());
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function  _beforeTokenTransfer (address from, address to, uint256 amount) internal override(ERC20, ERC20Snapshot) {
        if (advisorMode){
            require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Only Admin Role can perform transfers during Advisor Mode");
        }

        super._beforeTokenTransfer(from, to, amount);
    }


    // -------------------------------------------------------- admin

    function disableAdvisorMode() public onlyRole(DEFAULT_ADMIN_ROLE) {
        advisorMode = false;
        emit AdvisorModeOff(_msgSender(), block.timestamp);
    }

    function snapshot() public onlyRole(SNAPSHOT_ROLE) {
        _snapshot();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    // -------------------------------------------------------- view
    
    function getAdvisorMode() public view returns (bool) {
        return advisorMode;
    }


    // -------------------------------------------------------- events

    event AdvisorModeOff(address indexed from, uint time);


    // -------------------------------------------------------- Solidity
    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}
