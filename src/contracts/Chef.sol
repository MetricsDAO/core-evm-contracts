//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MetricToken.sol";

// POSSIBLE FUTURE ITERATIONS
// TODO implement claim(address)
// TODO implement staking function
// TODO implement payable function
// TODO implement withdrawl function
// TODO implement updatedAccumulatedAllocations

// TODO WE ADD THESE TO MAIN CHEF or should each contract have it's own
// TODO we make below more loosely coupled
// TODO viewPendingHarvest  
// TODO viewPendingClaims 

abstract contract Chef is Ownable {
    uint256 private _metricPerBlock;
    uint256 public constant ACC_METRIC_PRECISION = 1e12;

    bool private _rewardsActive;
    uint256 private _lastRewardBlock; 

    MetricToken private _metric;

    //------------------------------------------------------Setters

    function toggleRewards(bool isOn) public onlyOwner() {
        _rewardsActive = isOn;
        _lastRewardBlock = block.number;
    }

    function setMetricPerBlock(uint256 metricAmount) public virtual onlyOwner() {
        _metricPerBlock = metricAmount * 10**18;
    }

    function setLastRewardBlock(uint256 blockNumber) internal virtual {
        _lastRewardBlock = blockNumber;
    }

    function setMetricToken(address metricTokenAddress) public virtual onlyOwner() {
        _metric = MetricToken(metricTokenAddress);
    }

    //------------------------------------------------------Getters

    function getMetricPerBlock() public view virtual returns(uint256) {
        return _metricPerBlock;
    }

    function getLastRewardBlock() public view virtual returns(uint256) {
        return _lastRewardBlock;
    }

    function areRewardsActive() public view virtual returns (bool) {
        return _rewardsActive;
    }

    function getMetricToken() internal view virtual returns (MetricToken) {
        return _metric;
    }

    //------------------------------------------------------Support Functions

    mapping(address => bool) public addressExistence;
    modifier nonDuplicated(address _address) {
        require(addressExistence[_address] == false, "nonDuplicated: duplicated");
        addressExistence[_address] = true;
        _;
    }

    event Harvest(address harvester, uint256 agIndex, uint256 amount);
    event Withdraw(address withdrawer, uint256 agIndex, uint256 amount);

    receive() external payable virtual {}

    function withdrawMoney() public onlyOwner() {}

}
