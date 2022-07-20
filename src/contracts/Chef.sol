//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MetricToken.sol";

abstract contract Chef is Ownable {
    uint256 private _metricPerBlock;
    // This constant is used to remove the last 6 digits of METRIC to account for rounding issues
    uint256 public constant ACC_METRIC_PRECISION = 1e12;

    bool private _rewardsActive;
    uint256 private _lastRewardBlock;
    uint256 private _lifetimeShareValue;
    uint256 private _totalAllocShares;

    MetricToken private metric;

    //------------------------------------------------------Setters

    function toggleRewards(bool isOn) public onlyOwner {
        _rewardsActive = isOn;
        _setLastRewardBlock();
    }

    function setMetricPerBlock(uint256 metricAmount) public virtual onlyOwner {
        _metricPerBlock = metricAmount * 10**18;
    }

    function _setLastRewardBlock() internal virtual {
        _lastRewardBlock = block.number;
    }

    function setMetricToken(address metricTokenAddress) public virtual onlyOwner {
        metric = MetricToken(metricTokenAddress);
    }

    function setLifetimeShareValue() public virtual {
        if (!_rewardsActive) revert RewardsNotActive();
        uint256 accumulatedWithMetricPrecision = _getAcculatedWithmetricPrecision();
        _lifetimeShareValue = _lifetimeShareValue + accumulatedMetricDividedByShares(accumulatedWithMetricPrecision);
        _setLastRewardBlock();
    }

    function getLifeTimeShareValueEstimate() public view virtual returns (uint256) {
        uint256 accumulatedWithMetricPrecision = _getAcculatedWithmetricPrecision();
        uint256 lifetimesharevalue = _getLifetimeShareValue();
        return lifetimesharevalue + accumulatedMetricDividedByShares(accumulatedWithMetricPrecision);
    }

    function _addTotalAllocShares(uint256 shares) internal virtual {
        _totalAllocShares = _totalAllocShares + shares;
    }

    function _addTotalAllocShares(uint256 oldShares, uint256 newShares) internal virtual {
        if (oldShares > _totalAllocShares) revert InvalidShareAmount();
        _totalAllocShares = _totalAllocShares - oldShares + newShares;
    }

    function _removeAllocShares(uint256 oldShares) internal virtual {
        if (oldShares > _totalAllocShares) revert InvalidShareAmount();
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

    function _getAcculatedWithmetricPrecision() internal view virtual returns (uint256) {
        uint256 blocksSince = block.number - getLastRewardBlock();
        uint256 accumulated = blocksSince * getMetricPerBlock();
        return accumulated * ACC_METRIC_PRECISION;
    }

    function getTotalAllocationShares() public view returns (uint256) {
        return _totalAllocShares;
    }

    function _getLifetimeShareValue() internal view returns (uint256) {
        return _lifetimeShareValue;
    }

    function accumulatedMetricDividedByShares(uint256 accumulatedWithPrecision) public view returns (uint256) {
        if (getTotalAllocationShares() == 0) revert InvalidShareAmount();
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

    function renounceOwnership() public override onlyOwner {
        revert CannotRenounce();
    }

    //------------------------------------------------------Errors
    error DuplicateAddress();
    error CannotRenounce();
    error InvalidShareAmount();
    error RewardsNotActive();

    //------------------------------------------------------Events
    event Harvest(address indexed harvester, uint256 agIndex, uint256 amount);
    event Withdraw(address indexed withdrawer, uint256 agIndex, uint256 amount);
}
