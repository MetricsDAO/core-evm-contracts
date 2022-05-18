//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "./Chef.sol";

contract Staker is Chef {
    bool private _rewardsActive;
}

//staker struct {
        // address stakerAddress;
        // uint256 metricAmount;
        // bool autodistribute;
        // uint256 rewardDebt; // keeps track of how much the user is owed or has been credited already
        // uint256 claimable;
        // uint256 startDate;
// }