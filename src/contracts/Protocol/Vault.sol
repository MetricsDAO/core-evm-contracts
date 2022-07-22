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

    Status public status;
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

        lockedMetric[questionId].withdrawer = _withdrawer;
        lockedMetric[questionId].amount = _amount;

        lockedMetric[questionId].status = Status.DEPOSITED;

        depositsByWithdrawers[_withdrawer].push(questionId);
    }

    function withdrawMetric(uint256 questionId) external {
        if (!(msg.sender == lockedMetric[questionId].withdrawer)) revert NotTheWithdrawer();
        if (lockedMetric[questionId].amount == 0) revert NoMetricDeposited();
        if (!(_questionStateController.getState(questionId) == 3)) revert QuestionNotPublished();

        lockedMetric[questionId].status = Status.WITHDRAWN;

        emit Withdraw(msg.sender, lockedMetric[questionId].amount);
        SafeERC20.safeTransferFrom(_metric, address(this), msg.sender, lockedMetric[questionId].amount);
    }

    function slashMetric(uint256 questionId) external onlyOwner {
        if (!(lockedMetric[questionId].status == Status.SLASHED)) revert AlreadySlashed();

        lockedMetric[questionId].status = Status.SLASHED;

        emit Slash(msg.sender, questionId);
        SafeERC20.safeTransferFrom(_metric, address(this), address(0x4faFB87de15cFf7448bD0658112F4e4B0d53332c), lockedMetric[questionId].amount / 2);
        SafeERC20.safeTransferFrom(_metric, address(this), msg.sender, lockedMetric[questionId].amount / 2);
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
    error QuestionNotPublished();
    error AlreadySlashed();

    //------------------------------------------------------ Structs
    struct lockAttributes {
        address withdrawer;
        uint256 amount;
        Status status;
    }
    //------------------------------------------------------ Enums
    enum Status {
        UNINT,
        WITHDRAWN,
        DEPOSITED,
        PUBLISHED,
        SLASHED
    }
}
