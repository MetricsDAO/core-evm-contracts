// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../Enums/VaultEnum.sol";

interface IVault {
    function withdrawMetric(uint256 questionId, STAGE stage) external;
}
