//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./MetricToken.sol";

abstract contract Chef {
    using SafeMath for uint256;
    uint256 public _metricPerBlock;
    uint256 public constant ACC_METRIC_PRECISION = 1e12;

    bool private _rewardsActive; // DO WE MAKE ubiquitous per each chef? 

    MetricToken private _metric;

    function setMetricPerBlock(uint256 metricAmount) public {
        _metricPerBlock = metricAmount * 10**18;
    }

    function areRewardsActive() public view virtual returns (bool) {
        return _rewardsActive;
    }

    mapping(address => bool) public addressExistence;
    modifier nonDuplicated(address _address) {
        require(addressExistence[_address] == false, "nonDuplicated: duplicated");
        addressExistence[_address] = true;
        _;
    }

    event Harvest(address harvester, uint256 agIndex, uint256 amount);
    event Withdraw(address withdrawer, uint256 agIndex, uint256 amount);

}

// DO WE ADD THESE TO MAIN CHEF OR PER TYPE OF CHEF
// claim(address)
// payable staking function
// withdrawl function
// claim function 

// DO WE ADD THESE TO MAIN CHEF or should each contract have it's own
// DO we make below more loosely coupled
// viewPendingHarvest  
// viewPendingClaims 
