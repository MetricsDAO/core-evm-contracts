// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IQuestionStateController} from "./interfaces/IQuestionStateController.sol";
import {IClaimController} from "./interfaces/IClaimController.sol";
import {IBountyQuestion} from "./interfaces/IBountyQuestion.sol";

// Enums
import {STAGE, STATUS} from "./Enums/VaultEnum.sol";
import {STATE} from "./Enums/QuestionStateEnum.sol";
import {CLAIM_STATE} from "./Enums/ClaimEnum.sol";

// Structs
import {lockAttributes} from "./Structs/LockAttributes.sol";

// Errors
import {VaultEventsAndErrors} from "./EventsAndErrors/VaultEventsAndErrors.sol";

// Modifiers
import "./modifiers/OnlyCostController.sol";
import "./modifiers/OnlyAPI.sol";

contract Vault is Ownable, OnlyCostController, OnlyApi, VaultEventsAndErrors {
    IERC20 public metric;
    IQuestionStateController public questionStateController;
    IClaimController public claimController;
    IBountyQuestion public question;

    STATUS public status;

    /// @notice Address to the MetricsDAO treasury.
    address public treasury;
    address private constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    /// @notice Keeps track of the quantity of deposits per user.
    mapping(address => uint256[]) public depositsByWithdrawers;

    /// @notice Keeps track of the amount of METRIC locked per question
    mapping(uint256 => uint256) public lockedMetricByQuestion;

    /// @notice Keeps track of total amount in vault for a given user.
    mapping(address => uint256) public totalLockedInVaults;

    /// @notice Keeps track of the quantity of withdrawals per user.
    mapping(uint256 => mapping(STAGE => mapping(address => lockAttributes))) public lockedMetric;

    //------------------------------------------------------ CONSTRUCTOR

    /**
     * @notice Constructor sets the question Metric token, QuestionStateController and the treasury.
     * @param treasuryAddress The treasury address.
     */
    constructor(address treasuryAddress) {
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
        if (uint8(stage) > uint8(STAGE.PUBLISH)) revert InvalidStage();
        // Checks if there has not been a deposit yet
        // TODO remove amount!=0 possibly
        if (lockedMetric[questionId][stage][user].status != STATUS.UNINT) revert QuestionHasInvalidStatus();

        depositAccounting(user, amount, questionId, stage);
    }

    function burnMetric(address user, uint256 amount) external onlyCostController {
        metric.transferFrom(user, BURN_ADDRESS, amount);
    }

    /**
     * @notice Allows a user to withdraw METRIC locked for a question, after the question is published.
     * @param user The address of the user withdrawing the METRIC
     * @param questionId The question id
     * @param stage The stage for which the user is withdrawing metric from a question.
     */
    function withdrawMetric(
        address user,
        uint256 questionId,
        STAGE stage
    ) external onlyApi {
        // Checks if Metric is withdrawn for a valid stage.
        if (uint8(stage) > uint8(STAGE.REVIEW)) revert InvalidStage();

        if (stage == STAGE.CREATE_AND_VOTE) {
            // Checks that the question is published
            if (questionStateController.getState(questionId) != STATE.PUBLISHED) revert QuestionNotPublished();

            // Accounting & changes
            withdrawalAccounting(user, questionId, STAGE.CREATE_AND_VOTE);
        } else if (stage == STAGE.UNVOTE) {
            // Check that user has a voting index, has not voted and the question state is VOTING.
            if (question.getAuthorOfQuestion(questionId) == user) revert CannotUnvoteOwnQuestion();
            if (questionStateController.getHasUserVoted(user, questionId) == true) revert UserHasNotUnvoted();
            if (questionStateController.getState(questionId) != STATE.VOTING) revert QuestionNotInVoting();

            // Accounting & changes
            withdrawalAccounting(user, questionId, STAGE.CREATE_AND_VOTE);

            lockedMetric[questionId][STAGE.CREATE_AND_VOTE][user].status = STATUS.UNINT;
        } else if (stage == STAGE.CLAIM_AND_ANSWER) {
            if (questionStateController.getState(questionId) != STATE.COMPLETED) revert QuestionNotInReview();

            withdrawalAccounting(user, questionId, STAGE.CLAIM_AND_ANSWER);
        } else if (stage == STAGE.RELEASE_CLAIM) {
            if (questionStateController.getState(questionId) != STATE.PUBLISHED) revert QuestionNotPublished();
            if (claimController.getQuestionClaimState(questionId, user) != CLAIM_STATE.RELEASED) revert ClaimNotReleased();

            withdrawalAccounting(user, questionId, STAGE.CLAIM_AND_ANSWER);

            lockedMetric[questionId][STAGE.CLAIM_AND_ANSWER][user].status = STATUS.UNINT;
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

    function withdrawalAccounting(
        address user,
        uint256 questionId,
        STAGE stage
    ) internal {
        if (user != lockedMetric[questionId][stage][user].user) revert NotTheDepositor();
        if (lockedMetric[questionId][stage][user].status != STATUS.DEPOSITED) revert NoMetricDeposited();

        uint256 toWithdraw = lockedMetric[questionId][stage][user].amount;

        lockedMetric[questionId][stage][user].status = STATUS.WITHDRAWN;
        lockedMetric[questionId][stage][user].amount = 0;

        lockedMetricByQuestion[questionId] -= toWithdraw;
        totalLockedInVaults[user] -= toWithdraw;

        // Transfers Metric from the vault to the user.
        metric.transfer(user, toWithdraw);

        emit Withdraw(user, toWithdraw);
    }

    /**
     * @notice Allows anyone to update the controllers.
     */
    function updateStateController() public {
        questionStateController = IQuestionStateController(questionAPI.getQuestionStateController());
    }

    function updateClaimController() public {
        claimController = IClaimController(questionAPI.getClaimController());
    }

    function updateBountyQuestion() public {
        question = IBountyQuestion(questionAPI.getBountyQuestion());
    }

    function updateMetric() public {
        metric = IERC20(questionAPI.getMetricToken());
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

    //------------------------------------------------------ VIEW FUNCTIONS

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
     * @notice Allows owner to update the treasury address and questionApi.
     */
    function setTreasury(address _treasury) public onlyOwner {
        treasury = _treasury;
    }
}
