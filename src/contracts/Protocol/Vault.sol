// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./QuestionStateController.sol";
import "./interfaces/IQuestionStateController.sol";
import "./modifiers/OnlyCostController.sol";

contract Vault is Ownable, OnlyCostController {
    IERC20 public metric;
    IQuestionStateController public questionStateController;

    address public treasury;

    uint256 public depositsCount;

    mapping(address => uint256[]) public depositsByWithdrawers;
    mapping(uint256 => lockAttributes) public lockedMetric;

    STATUS public status;

    constructor(
        address _metricTokenAddress,
        address _questionStateController,
        address _treasury
    ) {
        metric = IERC20(_metricTokenAddress);
        questionStateController = IQuestionStateController(_questionStateController);
        treasury = _treasury;
    }

    /**
     * @notice Locks METRIC for creating a question
     * @param _withdrawer The address of the user locking the METRIC
     * @param _amount The amount of METRIC to lock
     * @param _questionId The question id
     */
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
        metric.transferFrom(_withdrawer, address(this), _amount);
    }

    /**
     * @notice Allows a user to withdraw METRIC locked for a question, after the question is published.
     * @param _questionId The question id
     */
    function withdrawMetric(uint256 _questionId) external {
        // Checks
        if (_msgSender() != lockedMetric[_questionId].withdrawer) revert NotTheWithdrawer();
        if (lockedMetric[_questionId].amount == 0) revert NoMetricToWithdraw();
        if (questionStateController.getState(_questionId) != uint256(IQuestionStateController.STATE.PUBLISHED)) revert QuestionNotPublished();

        // Effects
        uint256 toWithdraw = lockedMetric[_questionId].amount;

        lockedMetric[_questionId].status = STATUS.WITHDRAWN;
        lockedMetric[_questionId].amount = 0;

        // Interactions
        emit Withdraw(_msgSender(), toWithdraw);
        metric.transfer(_msgSender(), toWithdraw);
    }

    /**
     * @notice Allows onlyOwner to slash a question -- halfing the METRIC locked for the question.
     * @param _questionId The question id
     */
    function slashMetric(uint256 _questionId) external onlyOwner {
        if (lockedMetric[_questionId].status == STATUS.SLASHED) revert AlreadySlashed();

        lockedMetric[_questionId].status = STATUS.SLASHED;

        emit Slash(lockedMetric[_questionId].withdrawer, _questionId);

        // Send half to treasury
        metric.transfer(treasury, lockedMetric[_questionId].amount / 2);

        // Return half to user
        metric.transfer(lockedMetric[_questionId].withdrawer, lockedMetric[_questionId].amount / 2);
    }

    //------------------------------------------------------ Getters
    function getVaultsByWithdrawer(address _withdrawer) external view returns (uint256[] memory) {
        return depositsByWithdrawers[_withdrawer];
    }

    function getVaultById(uint256 _questionId) external view returns (lockAttributes memory) {
        return lockedMetric[_questionId];
    }

    function getMetricTotalLockedBalance() external view returns (uint256) {
        return metric.balanceOf(address(this));
    }

    //------------------------------------------------------ Events
    event Withdraw(address indexed withdrawer, uint256 indexed amount);
    event Slash(address indexed withdrawer, uint256 indexed questionId);

    //------------------------------------------------------ Errors
    error NotTheWithdrawer();
    error NoMetricToWithdraw();
<<<<<<< HEAD
    error NoMetricDeposited();
    error AlreadySlashed();
    error QuestionHasInvalidStatus();
=======
    error QuestionHasInvalidStatus();
    error QuestionNotPublished();
    error AlreadySlashed();
    error InvalidAddress();
>>>>>>> c62b2733d4871dcf473c08ed3a672f2ac3049e2c

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
    function setQuestionStateController(address _questionStateController) public onlyOwner {
        if (_questionStateController == address(0)) revert InvalidAddress();
        questionStateController = IQuestionStateController(_questionStateController);
    }

    function setTreasury(address _treasury) public onlyOwner {
        treasury = _treasury;
    }

    function setMetric(address _metric) public onlyOwner {
        if (_metric == address(0)) revert InvalidAddress();
        metric = IERC20(_metric);
    }
}
