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
    LockStates public currentState;

    constructor(address metricTokenAddress) {
        setMetricToken(metricTokenAddress);
    }

    function lockMetric(address _withdrawer, uint256 _amount) external returns (uint256 _id) {
        _metric.safeTransferFrom(msg.sender, address(this), _amount);

        walletMetricBalance[address(_metric)][msg.sender] = walletMetricBalance[address(_metric)][msg.sender].add(_amount);

        _id = ++depositsCount;
        lockedMetric[_id].withdrawer = _withdrawer;
        lockedMetric[_id].amount = _amount;

        setDeposited();

        depositsByMetricAddress[address(_metric)].push(_id);
        depositsByWithdrawers[_withdrawer].push(_id);
        return _id;
    }

    function withdrawMetric(uint256 _id) external {
        if (!(msg.sender == lockedMetric[_id].withdrawer)) revert NotTheWithdrawer();
        if (!(lockAttributes.currentState == deposited)) revert NoMetricDeposited();
        //TODO: question can be both published and deposotied
        if (!(lockAttributes.currentState == published)) revert QuestionNotPublished();
        if (lockAttributes.currentState == withdrawn) revert NoMetricToWithdraw();

        lockedMetric[_id].lockStates.withdrawn = true;

        walletMetricBalance[address(lockedMetric[_id].metric)][msg.sender] = walletMetricBalance[address(lockedMetric[_id].metric)][msg.sender].sub(
            lockedMetric[_id].amount
        );

        emit Withdraw(msg.sender, lockedMetric[_id].amount);
        lockedMetric[_id].metric.safeTransfer(msg.sender, lockedMetric[_id].amount);
    }

    function slashMetric(uint256 _id) external onlyOwner {
        if (!(lockAttributes.currentState == slashed)) revert AlreadySlashed();
        walletMetricBalance[address(lockedMetric[_id].metric)][msg.sender] = walletMetricBalance[address(lockedMetric[_id].metric)][msg.sender].sub(
            lockedMetric[_id].amount.div(2)
        );

        setSlashed();

        emit Withdraw(msg.sender, lockedMetric[_id].amount);
        lockedMetric[_id].metric.safeTransfer(address(0x4fafb87de15cff7448bd0658112f4e4b0d53332c), lockedMetric[_id].amount.div(2));
        lockedMetric[_id].metric.safeTransfer(msg.sender, lockedMetric[_id].amount.div(2));
    }

    //------------------------------------------------------ Setters
    function setWithdrawn() public {
        currentState = LockStates.withdrawn;
    }

    function setDeposited() public {
        currentState = LockStates.deposited;
    }

    function setPublished() public {
        currentState = LockStates.published;
    }

    function setSlashed() public {
        currentState = LockStates.slashed;
    }

    //------------------------------------------------------ Getters

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

    //------------------------------------------------------ Events
    event Withdraw(address withdrawer, uint256 amount);

    //------------------------------------------------------ Errors
    error NotTheWithdrawer();
    error NoMetricToWithdraw();
    error NoMetricDeposited();
    error QuestionNotPublished();
    error AlreadySlashed();

    //------------------------------------------------------ Structs
    struct lockAttributes {
        address withdrawer;
        uint256 amount;
        LockStates currentState;
    }
    //------------------------------------------------------ Enums
    enum LockStates {
        withdrawn,
        deposited,
        published,
        slashed
    }
}
