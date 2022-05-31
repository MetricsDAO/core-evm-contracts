//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
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
    using SafeMath for uint256;
    uint256 private _metricPerBlock;
    uint256 public constant ACC_METRIC_PRECISION = 1e12;

    bool private _rewardsActive;
    uint256 private _lastRewardBlock;
    uint256 private _lifetimeShareValue;
    uint256 private _totalAllocShares;

    MetricToken private metric; 
    //------------------------------------------------------Setters

    function toggleRewards(bool isOn) public onlyOwner() {
        _rewardsActive = isOn;
        setLastRewardBlock(block.number);
    }

    function setMetricPerBlock(uint256 metricAmount) public virtual onlyOwner() {
        _metricPerBlock = metricAmount * 10**18;
    }

    function setLastRewardBlock(uint256 blockNumber) internal virtual {
        _lastRewardBlock = blockNumber;
    }

    function setMetricToken(address metricTokenAddress) public virtual onlyOwner() {
        metric = MetricToken(metricTokenAddress);
    }

    function setLifetimeShareValue() public virtual {
        uint256 accumulated = getAccumulated();
        uint256 accumulatedWithMetricPrecision = getAcculatedWithmetricPrecision(accumulated);
        _lifetimeShareValue = _lifetimeShareValue.add(accumulatedMetricDividedByShares(accumulatedWithMetricPrecision));
    }

    function addTotalAllocShares(uint256 shares) internal virtual {
        _totalAllocShares = _totalAllocShares.add(shares);
    }

    function addTotalAllocShares(uint256 oldShares, uint256 newShares) internal virtual {
        _totalAllocShares = _totalAllocShares.sub(oldShares).add(newShares);
    }

    function removeAllocShares(uint256 oldShares) internal virtual {
        _totalAllocShares = _totalAllocShares.sub(oldShares);
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

    function getAccumulated() internal view virtual returns (uint256) {
        uint256 blocksSince = block.number.sub(getLastRewardBlock());
        return blocksSince.mul(getMetricPerBlock());
    }

    function getAcculatedWithmetricPrecision(uint accumulated) internal view virtual returns (uint) {
        return accumulated.mul(ACC_METRIC_PRECISION);
    }

    function getTotalAllocationShares() public view returns (uint256) {
        return _totalAllocShares;
    }

    function getLifetimeShareValue() public view returns (uint256) {
        return _lifetimeShareValue;
    }

    function accumulatedMetricDividedByShares(uint256 accumulatedWithPrecision) public view returns (uint256) {
        return accumulatedWithPrecision.div(getTotalAllocationShares());
    }

    function getMetricToken() public view returns (MetricToken) {
        return metric;
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

}
