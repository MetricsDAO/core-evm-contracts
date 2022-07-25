//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract OnlyCostController is Ownable {
    address public costController;

    // ------------------------------- Setter
    /**
     * @notice Sets the address of the ActionCostController.
     * @param _newCostController The new address of the ActionCostController.
     */
    function setCostController(address _newCostController) external onlyOwner {
        costController = _newCostController;
    }

    // ------------------------ Modifiers
    modifier onlyCostController() {
        if (_msgSender() != costController) revert NotTheCostController();
        _;
    }

    // ------------------------ Errors
    error NotTheCostController();
}
