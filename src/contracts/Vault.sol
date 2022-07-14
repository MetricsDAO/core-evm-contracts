// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Vault is Ownable {
    struct Items {
        IERC20 metric;
        address withdrawer;
        uint256 amount;
        uint256 unlockTimestamp;
        bool withdrawn;
        bool deposited;
    }

    uint256 public depositsCount;
    mapping(address => uint256[]) public depositsByMetricAddress;
    mapping(address => uint256[]) public depositsByWithdrawers;
    mapping(uint256 => Items) public lockedMetric;
    mapping(address => mapping(address => uint256)) public walletMetricBalance;

    event Withdraw(address withdrawer, uint256 amount);

    constructor() {}

    function lockMetric(
        IERC20 _metric,
        address _withdrawer,
        uint256 _amount,
        uint256 _unlockTimestamp
    ) external returns (uint256 _id) {
        require(_amount >= 500, "Metric amount too low!");
        require(_unlockTimestamp < 10000000000, "Unlock timestamp is not in seconds!");
        require(_unlockTimestamp > block.timestamp, "Unlock timestamp is not in the future!");
        require(_metric.allowance(msg.sender, address(this)) >= _amount, "Approve tokens first!");
        _metric.safeTransferFrom(msg.sender, address(this), _amount);

        walletMetricBalance[address(_metric)][msg.sender] = walletMetricBalance[address(_metric)][msg.sender].add(_amount);

        _id = ++depositsCount;
        lockedMetric[_id].metric = _metric;
        lockedMetric[_id].withdrawer = _withdrawer;
        lockedMetric[_id].amount = _amount;
        lockedMetric[_id].unlockTimestamp = _unlockTimestamp;
        lockedMetric[_id].withdrawn = false;
        lockedMetric[_id].deposited = true;

        depositsByMetricAddress[address(_metric)].push(_id);
        depositsByWithdrawers[_withdrawer].push(_id);
        return _id;
    }

    function withdrawmetrics(uint256 _id) external {
        require(block.timestamp >= lockedMetric[_id].unlockTimestamp, "Metrics are still locked!");
        require(msg.sender == lockedMetric[_id].withdrawer, "You are not the withdrawer!");
        require(lockedMetric[_id].deposited, "Metrics are not yet deposited!");
        require(!lockedMetric[_id].withdrawn, "Metrics are already withdrawn!");

        lockedMetric[_id].withdrawn = true;

        walletMetricBalance[address(lockedMetric[_id].metric)][msg.sender] = walletMetricBalance[address(lockedMetric[_id].metric)][msg.sender].sub(
            lockedMetric[_id].amount
        );

        emit Withdraw(msg.sender, lockedMetric[_id].amount);
        lockedMetric[_id].metric.safeTransfer(msg.sender, lockedMetric[_id].amount);
    }

    function getDepositsByMetricAddress(address _id) external view returns (uint256[] memory) {
        return depositsByMetricAddress[_id];
    }

    function getDepositsByWithdrawer(address _metric, address _withdrawer) external view returns (uint256) {
        return walletMetricBalance[_metric][_withdrawer];
    }

    function getVaultsByWithdrawer(address _withdrawer) external view returns (uint256[] memory) {
        return depositsByWithdrawers[_withdrawer];
    }

    function getVaultById(uint256 _id) external view returns (Items memory) {
        return lockedMetric[_id];
    }

    function getMetricTotalLockedBalance(address _metric) external view returns (uint256) {
        return IERC20(_metric).balanceOf(address(this));
    }
}
