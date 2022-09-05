// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./QuestionStateController.sol";
import "./BountyQuestion.sol";

// Interfaces
import "./interfaces/IQuestionStateController.sol";
import "./interfaces/IClaimController.sol";

// Enums
import "./Enums/VaultEnum.sol";
import "./Enums/QuestionStateEnum.sol";
import "./Enums/ClaimEnum.sol";

// Modifiers
import "./modifiers/OnlyCostController.sol";

contract Vault is Ownable, OnlyCostController {
    IERC20 public metric;
    IQuestionStateController public questionStateController;
    IClaimController public claimController;
    BountyQuestion private _question;

    STATUS public status;

    /// @notice Address to the MetricsDAO treasury.
    address public treasury;

    /// @notice Keeps track of the quantity of deposits per user.
    mapping(address => uint256[]) public depositsByWithdrawers;

    /// @notice Keeps track of the amount of METRIC locked per question
    mapping(uint256 => uint256) public lockedMetricByQuestion;

    /// @notice Keeps track of total amount in vault for a given user.
    mapping(address => uint256) public totalLockedInVaults;

    /// @notice Keeps track of the quantity of withdrawals per user.
    mapping(uint256 => mapping(STAGE => mapping(address => lockAttributes))) public lockedMetric;

    //------------------------------------------------------ ERRORS

    /// @notice Throw if user tries to withdraw Metric from a question it does not own.
    error NotTheDepositor();
    /// @notice Throw if user tries to withdraw Metric without having first deposited.
    error NoMetricDeposited();
    /// @notice Throw if user tries to lock Metric for a question that has a different state than UNINT.
    error QuestionHasInvalidStatus();
    /// @notice Throw if user tries to claim Metric for unvoting on a question that is not in the VOTING state.
    error QuestionNotInVoting();
    /// @notice Throw if user tries to claim Metric for a question that has not been published (yet).
    error QuestionNotPublished();
    /// @notice Throw if user tries to claim Metric for a question that was not unvoted
    error UserHasNotUnvoted();
    /// @notice Throw if user tries to withdraw Metric from a question that is not in the review state.
    error QuestionNotInReview();
    /// @notice Throw if user tries to withdraw Metric from a claim that is not released.
    error ClaimNotReleased();
    /// @notice Throw if creator of question tries to unvote
    error CannotUnvoteOwnQuestion();
    /// @notice Throw if the same question is slashed twice.
    error AlreadySlashed();
    /// @notice Throw if address is equal to address(0).
    error InvalidAddress();
    /// @notice Throw if user tries to lock METRIC for a stage that does not require locking.
    error InvalidStage();

    //------------------------------------------------------ STRUCTS

    struct lockAttributes {
        address user;
        uint256 amount;
        STATUS status;
    }

    //------------------------------------------------------ EVENTS

    /// @notice Event emitted when Metric is withdrawn.
    event Withdraw(address indexed user, uint256 indexed amount);
    /// @notice Event emitted when a question is slashed.
    event Slashed(address indexed user, uint256 indexed questionId);

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
     * @param user The address of the user locking the METRIC
     * @param amount The amount of METRIC to lock
     * @param questionId The question id'
     * @param stage The stage for which METRIC is locked
     */
    function lockMetric(
        address user,
        uint256 amount,
        uint256 questionId,
        STAGE stage
    ) external onlyCostController {
        // Checks if METRIC is locked for a valid stage.
        if (uint8(stage) >= 5) revert InvalidStage();
        // Checks if there has not been a deposit yet
        if (lockedMetric[questionId][stage][user].status != STATUS.UNINT) revert QuestionHasInvalidStatus();

        depositAccounting(user, amount, questionId, stage);
    }

    function burnMetric(address user, uint256 amount) external onlyCostController {
        metric.transferFrom(user, treasury, amount);
    }

    /**
     * @notice Allows a user to withdraw METRIC locked for a question, after the question is published.
     * @param questionId The question id
     * @param stage The stage for which the user is withdrawing metric from a question.
     */
    function withdrawMetric(uint256 questionId, STAGE stage) external {
        // Checks if Metric is withdrawn for a valid stage.
        if (uint8(stage) >= 5) revert InvalidStage();

        if (stage == STAGE.CREATE_AND_VOTE) {
            // Checks that the question is published
            if (questionStateController.getState(questionId) != STATE.PUBLISHED) revert QuestionNotPublished();

            // Accounting & changes
            withdrawalAccounting(questionId, STAGE.CREATE_AND_VOTE);
        } else if (stage == STAGE.UNVOTE) {
            // Check that user has a voting index, has not voted and the question state is VOTING.
            if (_question.getAuthorOfQuestion(questionId) == _msgSender()) revert CannotUnvoteOwnQuestion();
            if (questionStateController.getHasUserVoted(_msgSender(), questionId) == true) revert UserHasNotUnvoted();
            if (questionStateController.getState(questionId) != STATE.VOTING) revert QuestionNotInVoting();

            // Accounting & changes
            withdrawalAccounting(questionId, STAGE.CREATE_AND_VOTE);

            lockedMetric[questionId][STAGE.CREATE_AND_VOTE][_msgSender()].status = STATUS.UNINT;
        } else if (stage == STAGE.CLAIM_AND_ANSWER) {
            if (questionStateController.getState(questionId) != STATE.COMPLETED) revert QuestionNotInReview();

            withdrawalAccounting(questionId, STAGE.CLAIM_AND_ANSWER);
        } else if (stage == STAGE.RELEASE_CLAIM) {
            if (questionStateController.getState(questionId) != STATE.PUBLISHED) revert QuestionNotPublished();
            if (claimController.getQuestionClaimState(questionId, _msgSender()) != CLAIM_STATE.RELEASED) revert ClaimNotReleased();

            withdrawalAccounting(questionId, STAGE.CLAIM_AND_ANSWER);

            lockedMetric[questionId][STAGE.CLAIM_AND_ANSWER][_msgSender()].status = STATUS.UNINT;
        } else {
            // if (reviewPeriod == active) revert ReviewPeriodActive();
        }
    }

    function depositAccounting(
        address user,
        uint256 amount,
        uint256 questionId,
        STAGE stage
    ) internal {
        // Accounting & changes
        lockedMetric[questionId][stage][user].user = user;
        lockedMetric[questionId][stage][user].amount += amount;

        lockedMetricByQuestion[questionId] += amount;

        lockedMetric[questionId][stage][user].status = STATUS.DEPOSITED;

        totalLockedInVaults[user] += amount;
        depositsByWithdrawers[user].push(questionId);

        // Transfers Metric from the user to the vault.
        metric.transferFrom(user, address(this), amount);
    }

    function withdrawalAccounting(uint256 questionId, STAGE stage) internal {
        if (_msgSender() != lockedMetric[questionId][stage][_msgSender()].user) revert NotTheDepositor();
        if (lockedMetric[questionId][stage][_msgSender()].status != STATUS.DEPOSITED) revert NoMetricDeposited();

        uint256 toWithdraw = lockedMetric[questionId][stage][_msgSender()].amount;

        lockedMetric[questionId][stage][_msgSender()].status = STATUS.WITHDRAWN;
        lockedMetric[questionId][stage][_msgSender()].amount = 0;

        lockedMetricByQuestion[questionId] -= toWithdraw;
        totalLockedInVaults[_msgSender()] -= toWithdraw;

        // Transfers Metric from the vault to the user.
        metric.transfer(_msgSender(), toWithdraw);

        emit Withdraw(_msgSender(), toWithdraw);
    }

    /**
     * @notice Allows onlyOwner to slash a question -- halfing the METRIC locked for the question.
     * @param questionId The question id
     */
    // function slashMetric(uint256 questionId) external onlyOwner {
    //     // Check that the question has not been slashed yet.
    //     if (lockedMetric[questionId][0].status == STATUS.SLASHED) revert AlreadySlashed();

    //     lockedMetric[questionId][0].status = STATUS.SLASHED;

    //     // Send half of the Metric to the treasury
    //     metric.transfer(treasury, lockedMetricByQuestion[questionId] / 2);

    //     // Return the other half of the Metric to the user
    //     metric.transfer(lockedMetric[questionId][0].user, lockedMetric[questionId][0].amount / 2);

    //     emit Slashed(lockedMetric[questionId][0].user, questionId);
    // }

    /**
     * @notice Gets the questions that a user has created.
     * @param user The address of the user.
     * @return The questions that the user has created.
     */
    function getVaultsByWithdrawer(address user) external view returns (uint256[] memory) {
        return depositsByWithdrawers[user];
    }

    /**
     * @notice Gets the information about the vault attributes of a question.
     * @param questionId The question id.
     * @param stage The stage of the question.
     * @param user The address of the user.
     * @return A struct containing the attributes of the question (withdrawer, amount, status).
     */
    function getVaultById(
        uint256 questionId,
        STAGE stage,
        address user
    ) external view returns (lockAttributes memory) {
        return lockedMetric[questionId][stage][user];
    }

    function getLockedMetricByQuestion(uint256 questionId) public view returns (uint256) {
        return lockedMetricByQuestion[questionId];
    }

    function getUserFromProperties(
        uint256 questionId,
        STAGE stage,
        address user
    ) public view returns (address) {
        return lockedMetric[questionId][stage][user].user;
    }

    function getAmountFromProperties(
        uint256 questionId,
        STAGE stage,
        address user
    ) public view returns (uint256) {
        return lockedMetric[questionId][stage][user].amount;
    }

    function getLockedPerUser(address _user) public view returns (uint256) {
        return totalLockedInVaults[_user];
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

    function setClaimController(address _claimController) public onlyOwner {
        if (_claimController == address(0)) revert InvalidAddress();
        claimController = IClaimController(_claimController);
    }

    /**
     * @notice Allows owner to update the treasury address.
     */
    function setTreasury(address _treasury) public onlyOwner {
        treasury = _treasury;
    }

    function setBountyQuestion(address _bountyQuestion) public onlyOwner {
        _question = BountyQuestion(_bountyQuestion);
    }

    /**
     * @notice Allows owner to update the Metric token address.
     */
    function setMetric(address _metric) public onlyOwner {
        if (_metric == address(0)) revert InvalidAddress();
        metric = IERC20(_metric);
    }
}
