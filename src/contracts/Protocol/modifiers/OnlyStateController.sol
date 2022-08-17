//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract OnlyStateController is Ownable {
    address public stateController;

    // ------------------------------- Setter
    /**
     * @notice Sets the address of the QuestionStateController.
     * @param _newStateController The new address of the QuestionStateController.
     */
    function setStateController(address _newStateController) external onlyOwner {
        stateController = _newStateController;
    }

    // ------------------------ Modifiers
    modifier onlyStateController() {
        if (_msgSender() != stateController) revert NotTheStateController();
        _;
    }

    // ------------------------ Errors
    error NotTheStateController();
}
