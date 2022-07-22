// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./QuestionStateController.sol";
import "./interfaces/IQuestionStateController.sol";

contract Vault is Ownable {
    IERC20 private _metric;
    uint256 public depositsCount;
    mapping(address => uint256[]) public depositsByWithdrawers;
    mapping(uint256 => lockAttributes) public lockedMetric;
    LockStates currentState;
    IQuestionStateController private _questionStateController;

    constructor(address metricTokenAddress, address questionStateController) {
        _metric = IERC20(metricTokenAddress);
        _questionStateController = IQuestionStateController(questionStateController);
    }

    function lockMetric(
        address _withdrawer,
        uint256 _amount,
        uint256 questionId
    ) external {
        SafeERC20.safeTransferFrom(_metric, msg.sender, address(this), _amount);

        // walletMetricBalance[address(_metric)][msg.sender] = walletMetricBalance[address(_metric)][msg.sender].add(_amount);

        lockedMetric[questionId].withdrawer = _withdrawer;
        lockedMetric[questionId].amount = _amount;

        setDeposited();

        depositsByWithdrawers[_withdrawer].push(questionId);
    }

    function withdrawMetric(uint256 questionId) external {
        if (!(msg.sender == lockedMetric[questionId].withdrawer)) revert NotTheWithdrawer();
        // if (!(lockAttributes[questionId].state == LockStates.DEPOSITED)) revert NoMetricDeposited();
        if (!(_questionStateController.getState(questionId) == 3)) revert QuestionNotPublished();
        // if (lockAttributes.state == LockStates.WITHDRAWN) revert NoMetricToWithdraw();

        setWithdrawn();

        // walletMetricBalance[address(lockedMetric[questionId].metric)][msg.sender] = walletMetricBalance[address(lockedMetric[questionId].metric)][
        //     msg.sender
        // ].sub(lockedMetric[questionId].amount);

        emit Withdraw(msg.sender, lockedMetric[questionId].amount);
        SafeERC20.safeTransferFrom(_metric, address(this), msg.sender, lockedMetric[questionId].amount);
    }

    function slashMetric(uint256 questionId) external onlyOwner {
        // if (!(lockAttributes.state == LockStates.SLASHED)) revert AlreadySlashed();
        // walletMetricBalance[address(lockedMetric[questionId].metric)][msg.sender] = walletMetricBalance[address(lockedMetric[questionId].metric)][
        //     msg.sender
        // ].sub(lockedMetric[questionId].amount.div(2));

        setSlashed();

        emit Slash(msg.sender, questionId);
        SafeERC20.safeTransferFrom(_metric, address(this), address(0x4faFB87de15cFf7448bD0658112F4e4B0d53332c), lockedMetric[questionId].amount / 2);
        SafeERC20.safeTransferFrom(_metric, address(this), msg.sender, lockedMetric[questionId].amount / 2);
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

    // function getDepositsByWithdrawer(address _withdrawer) external view returns (uint256) {
    //     return walletMetricBalance[_metric][_withdrawer];
    // }

    function getVaultsByWithdrawer(address _withdrawer) external view returns (uint256[] memory) {
        return depositsByWithdrawers[_withdrawer];
    }

    function getVaultById(uint256 questionId) external view returns (lockAttributes memory) {
        return lockedMetric[questionId];
    }

    function getMetricTotalLockedBalance() external view returns (uint256) {
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

    enum STATE {
        UNINIT,
        VOTING,
        PUBLISHED,
        IN_GRADING,
        COMPLETED,
        CANCELLED,
        BAD
    }
}
