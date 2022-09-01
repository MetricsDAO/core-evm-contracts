//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

// Interfaces
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "../interfaces/IClaimController.sol";

abstract contract TokenBar is Ownable {
    address public metricToken;

    /// @notice Throw if user tries to claim with balance lower than threshold
    error NotEnoughTokens();

    function setMetricToken(address _metricToken) public onlyOwner {
        metricToken = _metricToken;
    }

    modifier tokenThreshold(address user, uint256 questionId) {
        checkThreshold(user, questionId);
        _;
    }

    function checkThreshold(address user, uint256 questionId) internal view virtual {
        if (IERC20(metricToken).balanceOf(user) < IClaimController(address(this)).getMetricThreshold(questionId)) revert NotEnoughTokens();
    }
}
