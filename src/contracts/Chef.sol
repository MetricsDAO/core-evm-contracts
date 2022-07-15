//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

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
    uint256 private _lifetimeShareValue;
    uint256 private _totalAllocShares;

    MetricToken private metric;

    //------------------------------------------------------Setters

    function toggleRewards(bool isOn) public onlyOwner {
        _rewardsActive = isOn;
        setLastRewardBlock(block.number);
    }

    function setMetricPerBlock(uint256 metricAmount) public virtual onlyOwner {
        _metricPerBlock = metricAmount * 10**18;
    }

    function setLastRewardBlock(uint256 blockNumber) internal virtual {
        _lastRewardBlock = blockNumber;
    }

    function setMetricToken(address metricTokenAddress) public virtual onlyOwner {
        metric = MetricToken(metricTokenAddress);
    }

    function setLifetimeShareValue() public virtual {
        uint256 accumulated = getAccumulated();
        uint256 accumulatedWithMetricPrecision = getAcculatedWithmetricPrecision(accumulated);
        _lifetimeShareValue = _lifetimeShareValue + accumulatedMetricDividedByShares(accumulatedWithMetricPrecision);
    }

    function getLifeTimeShareValueEstimate() public view virtual returns (uint256) {
        uint256 accumulated = getAccumulated();
        uint256 accumulatedWithMetricPrecision = getAcculatedWithmetricPrecision(accumulated);
        uint256 lifetimesharevalue = getLifetimeShareValue();
        return lifetimesharevalue + accumulatedMetricDividedByShares(accumulatedWithMetricPrecision);
    }

    function addTotalAllocShares(uint256 shares) internal virtual {
        _totalAllocShares = _totalAllocShares + shares;
    }

    function addTotalAllocShares(uint256 oldShares, uint256 newShares) internal virtual {
        _totalAllocShares = _totalAllocShares - oldShares + newShares;
    }

    function removeAllocShares(uint256 oldShares) internal virtual {
        _totalAllocShares = _totalAllocShares - oldShares;
    }

    //------------------------------------------------------Getters

    function getMetricPerBlock() public view virtual returns (uint256) {
        return _metricPerBlock;
    }

    function getLastRewardBlock() public view virtual returns (uint256) {
        return _lastRewardBlock;
    }

    function areRewardsActive() public view virtual returns (bool) {
        return _rewardsActive;
    }

    function getAccumulated() internal view virtual returns (uint256) {
        uint256 blocksSince = block.number - getLastRewardBlock();
        return blocksSince * getMetricPerBlock();
    }

    function getAcculatedWithmetricPrecision(uint256 accumulated) internal view virtual returns (uint256) {
        return accumulated * ACC_METRIC_PRECISION;
    }

    function getTotalAllocationShares() public view returns (uint256) {
        return _totalAllocShares;
    }

    function getLifetimeShareValue() internal view returns (uint256) {
        return _lifetimeShareValue;
    }

    function accumulatedMetricDividedByShares(uint256 accumulatedWithPrecision) public view returns (uint256) {
        return accumulatedWithPrecision / getTotalAllocationShares();
    }

    function getMetricToken() public view returns (MetricToken) {
        return metric;
    }

    //------------------------------------------------------Support Functions

    mapping(address => bool) public addressExistence;
    modifier nonDuplicated(address _address) {
        if (addressExistence[_address] == true) revert DuplicateAddress();
        addressExistence[_address] = true;
        _;
    }

    //------------------------------------------------------Errors
    error DuplicateAddress();

    //------------------------------------------------------Events
    event Harvest(address harvester, uint256 agIndex, uint256 amount);
    event Withdraw(address withdrawer, uint256 agIndex, uint256 amount);
}
