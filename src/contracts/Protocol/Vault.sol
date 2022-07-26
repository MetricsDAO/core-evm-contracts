// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./QuestionStateController.sol";
import "./interfaces/IQuestionStateController.sol";
import "./modifiers/OnlyCostController.sol";

contract Vault is Ownable, OnlyCostController {
    IERC20 private _metric;
    uint256 public depositsCount;
    mapping(address => uint256[]) public depositsByWithdrawers;
    mapping(uint256 => lockAttributes) public lockedMetric;

    STATUS public status;
    IQuestionStateController private _questionStateController;

    constructor(address metricTokenAddress, address questionStateController) {
        _metric = IERC20(metricTokenAddress);
        _questionStateController = IQuestionStateController(questionStateController);
    }

    function lockMetric(
        address _withdrawer,
        uint256 _amount,
        uint256 _questionId
    ) external onlyCostController {
        //Checks
        if (lockedMetric[_questionId].status != STATUS.UNINT) revert QuestionHasInvalidStatus();

        // Effects
        lockedMetric[_questionId].withdrawer = _withdrawer;
        lockedMetric[_questionId].amount += _amount;

        lockedMetric[_questionId].status = STATUS.DEPOSITED;

        depositsByWithdrawers[_withdrawer].push(_questionId);

        // Interactions
        _metric.transferFrom(_withdrawer, address(this), _amount);
    }

    function withdrawMetric(address _withdrawer, uint256 questionId) external {
        if (!(_withdrawer == lockedMetric[questionId].withdrawer)) revert NotTheWithdrawer();
        if (lockedMetric[questionId].amount == 0) revert NoMetricDeposited();
        if (!(_questionStateController.getState(questionId) == 3)) revert QuestionNotPublished();

        lockedMetric[questionId].status = STATUS.WITHDRAWN;

        emit Withdraw(_withdrawer, lockedMetric[questionId].amount);
        _metric.transferFrom(address(this), _withdrawer, lockedMetric[questionId].amount);
    }

    function slashMetric(address _user, uint256 questionId) external onlyOwner {
        if (lockedMetric[questionId].status == STATUS.SLASHED) revert AlreadySlashed();

        lockedMetric[questionId].status = STATUS.SLASHED;

        emit Slash(_msgSender(), questionId);
        _metric.transferFrom(address(this), address(0x4faFB87de15cFf7448bD0658112F4e4B0d53332c), lockedMetric[questionId].amount / 2);
        _metric.transferFrom(address(this), _user, lockedMetric[questionId].amount / 2);
    }

    //------------------------------------------------------ Getters
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
    error AlreadySlashed();
    error QuestionHasInvalidStatus();

    //------------------------------------------------------ Structs
    struct lockAttributes {
        address withdrawer;
        uint256 amount;
        STATUS status;
    }

    //------------------------------------------------------ Enums
    enum STATUS {
        UNINT,
        WITHDRAWN,
        DEPOSITED,
        PUBLISHED,
        SLASHED
    }

    //------------------------------------------------------ Admin functions
    function setQuestionStateController(address questionStateController) external onlyOwner {
        _questionStateController = IQuestionStateController(questionStateController);
    }

    function setMetric(address metric) public onlyOwner {
        _metric = IERC20(metric);
    }
}
