//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {STATUS} from "../Enums/VaultEnum.sol";

struct lockAttributes {
    address user;
    uint256 amount;
    STATUS status;
}
