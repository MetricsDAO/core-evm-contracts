//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ITokenVault.sol";

contract TokenVault is Ownable, ITokenVault {}
