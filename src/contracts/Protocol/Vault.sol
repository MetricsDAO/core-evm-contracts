// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./QuestionStateController.sol";

contract Vault is Ownable {
    uint256 public depositsCount;
    mapping(address => uint256[]) public depositsByWithdrawers;
    mapping(uint256 => lockAttributes) public lockedMetric;
    mapping(address => mapping(address => uint256)) public walletMetricBalance;
    // mapping(uint256 => lockedMetric) question;
    LockStates public currentState;

    constructor(address metricTokenAddress, address questionStateController) {
        setMetricToken(metricTokenAddress);
        _questionStateController = IQuestionStateController(questionStateController);
    }

    function lockMetric(
        address _withdrawer,
        uint256 _amount,
        uint256 questionId
    ) external returns (uint256 _id) {
        _metric.safeTransferFrom(msg.sender, address(this), _amount);

        walletMetricBalance[address(_metric)][msg.sender] = walletMetricBalance[address(_metric)][msg.sender].add(_amount);

        _id = ++depositsCount;
        lockedMetric[_id].withdrawer = _withdrawer;
        lockedMetric[_id].amount = _amount;

        lockedMetric[_id].state = setDeposited();

        depositsByMetricAddress[address(_metric)].push(_id);
        depositsByWithdrawers[_withdrawer].push(_id);
        return _id;
    }

    function withdrawMetric(uint256 _id) external {
        if (!(msg.sender == lockedMetric[_id].withdrawer)) revert NotTheWithdrawer();
        if (!(lockAttributes.currentState == DEPOSITED)) revert NoMetricDeposited();
        if (!(_questionStateController.getState(questionId) == PUBLISHED)) revert QuestionNotPublished();
        if (lockAttributes.currentState == WITHDRAWN) revert NoMetricToWithdraw();

        lockedMetric[_id].state = setWithdrawn();

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

        lockedMetric[_id].state = setSlashed();

        emit slash(msg.sender, questionId);
        lockedMetric[_id].metric.safeTransfer(address(0x4fafb87de15cff7448bd0658112f4e4b0d53332c), lockedMetric[_id].amount.div(2));
        lockedMetric[_id].metric.safeTransfer(msg.sender, lockedMetric[_id].amount.div(2));
    }

    //------------------------------------------------------ Setters
    function setWithdrawn() public {
        currentState = LockStates.WITHDRAWN;
    }

    function setDeposited() public {
        currentState = LockStates.DEPOSITED;
    }

    function setSlashed() public {
        currentState = LockStates.SLASHED;
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
    event Slash(address withdrawer, uint256 questionId);

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
        LockStates state;
    }
    //------------------------------------------------------ Enums
    enum LockStates {
        UNINT,
        WITHDRAWN,
        DEPOSITED,
        SLASHED
    }
}
