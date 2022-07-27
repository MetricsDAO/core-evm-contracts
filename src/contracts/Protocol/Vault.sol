// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./QuestionStateController.sol";

// Interfaces
import "./interfaces/IQuestionStateController.sol";

// Modifiers
import "./modifiers/OnlyCostController.sol";

contract Vault is Ownable, OnlyCostController {
    IERC20 public metric;
    IQuestionStateController public questionStateController;

    STATUS public status;

    /// @notice Address to the MetricsDAO treasury.
    address public treasury;

    /// @notice Keeps track of the quantity of deposits per user.
    mapping(address => uint256[]) public depositsByWithdrawers;

    /// @notice Keeps track of the quantity of withdrawals per user.
    mapping(uint256 => lockAttributes) public lockedMetric;

    //------------------------------------------------------ ERRORS

    /// @notice Throw if user tries to withdraw Metric from a question it does not own.
    error NotTheWithdrawer();
    /// @notice Throw if user tries to withdraw Metric while the amount of metric to withdraw is equal to 0.
    error NoMetricToWithdraw();
    /// @notice Throw if user tries to lock Metric for a question that has a different state than UNINT.
    error QuestionHasInvalidStatus();
    /// @notice Throw if user tries to claim Metric for a question that has not been published (yet).
    error QuestionNotPublished();
    /// @notice Throw if the same question is slashed twice.
    error AlreadySlashed();
    /// @notice Throw if address is equal to address(0).
    error InvalidAddress();

    //------------------------------------------------------ STRUCTS

    struct lockAttributes {
        address withdrawer;
        uint256 amount;
        STATUS status;
    }

    //------------------------------------------------------ ENUMS

    enum STATUS {
        UNINT,
        WITHDRAWN,
        DEPOSITED,
        PUBLISHED,
        SLASHED
    }

    //------------------------------------------------------ EVENTS

    /// @notice Event emitted when Metric is withdrawn.
    event Withdraw(address indexed withdrawer, uint256 indexed amount);
    /// @notice Event emitted when a question is slashed.
    event Slash(address indexed withdrawer, uint256 indexed questionId);

    //------------------------------------------------------ CONSTRUCTOR

    /**
     * @notice Constructor sets the question Metric token, QuestionStateController and the treasury.
     * @param metricTokenAddress The Metric token address
     * @param questionStateControllerAddress The QuestionStateController address.
     * @param treasuryAddress The treasury address.
     */
    constructor(
        address metricTokenAddress,
        address questionStateControllerAddress,
        address treasuryAddress
    ) {
        metric = IERC20(metricTokenAddress);
        questionStateController = IQuestionStateController(questionStateControllerAddress);
        treasury = treasuryAddress;
    }

    //------------------------------------------------------ FUNCTIONS

    /**
     * @notice Locks METRIC for creating a question
     * @param withdrawer The address of the user locking the METRIC
     * @param amount The amount of METRIC to lock
     * @param questionId The question id
     */
    function lockMetric(
        address withdrawer,
        uint256 amount,
        uint256 questionId
    ) external onlyCostController {
        // Checks if there has not been a deposit yet
        if (lockedMetric[questionId].status != STATUS.UNINT) revert QuestionHasInvalidStatus();

        // Accounting & changes
        lockedMetric[questionId].withdrawer = withdrawer;
        lockedMetric[questionId].amount += amount;

        lockedMetric[questionId].status = STATUS.DEPOSITED;

        depositsByWithdrawers[withdrawer].push(questionId);

        // Transfers Metric from the user to the vault.
        metric.transferFrom(withdrawer, address(this), amount);
    }

    /**
     * @notice Allows a user to withdraw METRIC locked for a question, after the question is published.
     * @param questionId The question id
     */
    function withdrawMetric(uint256 questionId) external {
        // Checks that only the depositer can withdraw the metric
        if (_msgSender() != lockedMetric[questionId].withdrawer) revert NotTheWithdrawer();
        // Checks that the metric to withdraw is not 0
        if (lockedMetric[questionId].amount == 0) revert NoMetricToWithdraw();
        // Checks that the question is published
        if (questionStateController.getState(questionId) != uint256(IQuestionStateController.STATE.PUBLISHED)) revert QuestionNotPublished();

        // Accounting & changes
        uint256 toWithdraw = lockedMetric[questionId].amount;

        lockedMetric[questionId].status = STATUS.WITHDRAWN;
        lockedMetric[questionId].amount = 0;

        // Transfers Metric from the vault to the user.
        emit Withdraw(_msgSender(), toWithdraw);
        metric.transfer(_msgSender(), toWithdraw);
    }

    /**
     * @notice Allows onlyOwner to slash a question -- halfing the METRIC locked for the question.
     * @param questionId The question id
     */
    function slashMetric(uint256 questionId) external onlyOwner {
        // Check that the question has not been slashed yet.
        if (lockedMetric[questionId].status == STATUS.SLASHED) revert AlreadySlashed();

        lockedMetric[questionId].status = STATUS.SLASHED;

        emit Slash(lockedMetric[questionId].withdrawer, questionId);

        // Send half of the Metric to the treasury
        metric.transfer(treasury, lockedMetric[questionId].amount / 2);

        // Return the other half of the Metric to the user
        metric.transfer(lockedMetric[questionId].withdrawer, lockedMetric[questionId].amount / 2);
    }

    /**
     * @notice Gets the questions that a user has created.
     * @param withdrawer The address of the user.
     * @return The questions that the user has created.
     */
    function getVaultsByWithdrawer(address withdrawer) external view returns (uint256[] memory) {
        return depositsByWithdrawers[withdrawer];
    }

    /**
     * @notice Gets the information about the attributes of a question.
     * @param questionId The question id.
     * @return A struct containing the attributes of the question (withdrawer, amount, status).
     */
    function getVaultById(uint256 questionId) external view returns (lockAttributes memory) {
        return lockedMetric[questionId];
    }

    /**
     * @notice Gets the total amount of Metric locked in the vault.
     * @return The total amount of Metric locked in the vault.
     */
    function getMetricTotalLockedBalance() external view returns (uint256) {
        return metric.balanceOf(address(this));
    }

    //------------------------------------------------------ OWNER FUNCTIONS

    /**
     * @notice Allows owner to update the QuestionStateController.
     */
    function setQuestionStateController(address _questionStateController) public onlyOwner {
        if (_questionStateController == address(0)) revert InvalidAddress();
        questionStateController = IQuestionStateController(_questionStateController);
    }

    /**
     * @notice Allows owner to update the treasury address.
     */
    function setTreasury(address _treasury) public onlyOwner {
        treasury = _treasury;
    }

    /**
     * @notice Allows owner to update the Metric token address.
     */
    function setMetric(address _metric) public onlyOwner {
        if (_metric == address(0)) revert InvalidAddress();
        metric = IERC20(_metric);
    }
}
