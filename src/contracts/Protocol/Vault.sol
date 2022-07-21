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
    LockStates public currentState;

    constructor(address metricTokenAddress, address questionStateController) {
        setMetricToken(metricTokenAddress);
        _questionStateController = IQuestionStateController(questionStateController);
    }

    function lockMetric(
        address _withdrawer,
        uint256 _amount,
        uint256 questionId
    ) external {
        _metric.safeTransferFrom(msg.sender, address(this), _amount);

        walletMetricBalance[address(_metric)][msg.sender] = walletMetricBalance[address(_metric)][msg.sender].add(_amount);

        lockedMetric[questionId].withdrawer = _withdrawer;
        lockedMetric[questionId].amount = _amount;

        lockedMetric[questionId].state = setDeposited();

        depositsByMetricAddress[address(_metric)].push(questionId);
        depositsByWithdrawers[_withdrawer].push(QuestionId);
    }

    function withdrawMetric(uint256 questionId) external {
        if (!(msg.sender == lockedMetric[questionId].withdrawer)) revert NotTheWithdrawer();
        if (!(lockAttributes.currentState == DEPOSITED)) revert NoMetricDeposited();
        if (!(_questionStateController.getState(questionId) == PUBLISHED)) revert QuestionNotPublished();
        if (lockAttributes.currentState == WITHDRAWN) revert NoMetricToWithdraw();

        lockedMetric[questionId].state = setWithdrawn();

        walletMetricBalance[address(lockedMetric[questionId].metric)][msg.sender] = walletMetricBalance[address(lockedMetric[questionId].metric)][
            msg.sender
        ].sub(lockedMetric[questionId].amount);

        emit Withdraw(msg.sender, lockedMetric[questionId].amount);
        lockedMetric[questionId].metric.safeTransfer(msg.sender, lockedMetric[questionId].amount);
    }

    function slashMetric(uint256 questionId) external onlyOwner {
        if (!(lockAttributes.currentState == slashed)) revert AlreadySlashed();
        walletMetricBalance[address(lockedMetric[questionId].metric)][msg.sender] = walletMetricBalance[address(lockedMetric[questionId].metric)][
            msg.sender
        ].sub(lockedMetric[questionId].amount.div(2));

        lockedMetric[questionId].state = setSlashed();

        emit slash(msg.sender, questionId);
        lockedMetric[questionId].metric.safeTransfer(address(0x4fafb87de15cff7448bd0658112f4e4b0d53332c), lockedMetric[questionId].amount.div(2));
        lockedMetric[questionId].metric.safeTransfer(msg.sender, lockedMetric[questionId].amount.div(2));
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

    function getDepositsByMetricAddress(address questionId) external view returns (uint256[] memory) {
        return depositsByMetricAddress[questionId];
    }

    function getDepositsByWithdrawer(address _metric, address _withdrawer) external view returns (uint256) {
        return walletMetricBalance[_metric][_withdrawer];
    }

    function getVaultsByWithdrawer(address _withdrawer) external view returns (uint256[] memory) {
        return depositsByWithdrawers[_withdrawer];
    }

    function getVaultById(uint256 questionId) external view returns (Items memory) {
        return lockedMetric[questionId];
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
