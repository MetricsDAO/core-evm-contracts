// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Vault is Ownable {
    uint256 public depositsCount;
    mapping(address => uint256[]) public depositsByWithdrawers;
    mapping(uint256 => Items) public lockedMetric;
    mapping(address => mapping(address => uint256)) public walletMetricBalance;

    constructor(address metricTokenAddress) {
        setMetricToken(metricTokenAddress);
    }

    function lockMetric(
        address _withdrawer,
        uint256 _amount,
        uint256 _unlockTimestamp
    ) external returns (uint256 _id) {
        _metric.safeTransferFrom(msg.sender, address(this), _amount);

        walletMetricBalance[address(_metric)][msg.sender] = walletMetricBalance[address(_metric)][msg.sender].add(_amount);

        _id = ++depositsCount;
        lockedMetric[_id].withdrawer = _withdrawer;
        lockedMetric[_id].amount = _amount;
        lockedMetric[_id].unlockTimestamp = _unlockTimestamp;
        lockedMetric[_id].withdrawn = false;
        lockedMetric[_id].deposited = true;
        lockedMetric[_id].published = false;
        lockedMetric[_id].disqualified = false;

        depositsByMetricAddress[address(_metric)].push(_id);
        depositsByWithdrawers[_withdrawer].push(_id);
        return _id;
    }

    function withdrawMetric(uint256 _id) external {
        require(msg.sender == lockedMetric[_id].withdrawer, "You are not the withdrawer!");
        require(lockedMetric[_id].deposited, "No Metric Deposited!");
        require(lockedMetric[_id].published, "Question has not been published");
        require(!lockedMetric[_id].withdrawn, "Metric already withdrawn!");

        lockedMetric[_id].withdrawn = true;

        walletMetricBalance[address(lockedMetric[_id].metric)][msg.sender] = walletMetricBalance[address(lockedMetric[_id].metric)][msg.sender].sub(
            lockedMetric[_id].amount
        );

        emit Withdraw(msg.sender, lockedMetric[_id].amount);
        lockedMetric[_id].metric.safeTransfer(msg.sender, lockedMetric[_id].amount);
    }

    //TODO: Double check math
    function slashMetric(uint256 _id) external onlyOwner {
        walletMetricBalance[address(lockedMetric[_id].metric)][msg.sender] = walletMetricBalance[address(lockedMetric[_id].metric)][msg.sender].sub(
            lockedMetric[_id].amount.div(2)
        );

        emit Withdraw(msg.sender, lockedMetric[_id].amount);
        //TODO: send to treasury
        lockedMetric[_id].metric.safeTransfer(address(this), lockedMetric[_id].amount.div(2));
        lockedMetric[_id].metric.safeTransfer(msg.sender, lockedMetric[_id].amount.div(2));
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

    event Withdraw(address withdrawer, uint256 amount);

    struct Items {
        address withdrawer;
        uint256 amount;
        uint256 unlockTimestamp;
        bool withdrawn;
        bool deposited;
        bool published;
        bool disqualified;
    }
}
