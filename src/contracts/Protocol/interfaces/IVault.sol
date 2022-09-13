// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../Enums/VaultEnum.sol";

interface IVault {
    function withdrawMetric(
        address user,
        uint256 questionId,
        STAGE stage
    ) external;

    function lockMetric(
        address user,
        uint256 amount,
        uint256 questionId,
        STAGE stage
    ) external;

    function burnMetric(address user, uint256 amount) external;
}
