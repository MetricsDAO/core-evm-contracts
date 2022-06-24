//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./TopChef.sol";

contract InvestorChef is TopChef {
    address public groupAddress;
    uint256 public agIndex;
    uint256 public shares;
    bool public newAutoDistribute;

    constructor(address metricTokenAddress) TopChef(metricTokenAddress) {
        setMetricToken(metricTokenAddress);
        setMetricPerBlock(4);
        toggleRewards(false); // locking contract initially
        updateAllocationGroup(groupAddress, agIndex, shares, newAutoDistribute);
        viewPendingHarvest(agIndex);
        viewPendingClaims(agIndex);
        harvestAll();
        harvest(agIndex);
        claim(agIndex);
    }
}
