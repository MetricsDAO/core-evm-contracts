// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "@contracts/MetricToken.sol";
import "@contracts/Protocol/QuestionAPI.sol";
import "@contracts/Protocol/ClaimController.sol";
import "@contracts/Protocol/QuestionStateController.sol";
import "@contracts/Protocol/BountyQuestion.sol";
import "@contracts/Protocol/ActionCostController.sol";
import "@contracts/Protocol/Vault.sol";
import {NFT} from "@contracts/Protocol/Extra/MockAuthNFT.sol";

import "../../contracts/Protocol/Enums/ActionEnum.sol";
import "../../contracts/Protocol/Enums/VaultEnum.sol";
import "../../contracts/Protocol/Enums/QuestionStateEnum.sol";
import "../../contracts/Protocol/Enums/ClaimEnum.sol";

contract VotingTest is Test {
    // Roles
    bytes32 public constant PROGRAM_MANAGER_ROLE = keccak256("PROGRAM_MANAGER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Accounts
    address owner = address(0x0a);
    address other = address(0x0b);
    address other2 = address(0x0e);
    address manager = address(0x0c);
    address treasury = address(0x0d);
    address other3 = address(0x0f);

    MetricToken _metricToken;
    QuestionAPI _questionAPI;
    BountyQuestion _bountyQuestion;
    ClaimController _claimController;
    ActionCostController _costController;
    QuestionStateController _questionStateController;
    Vault _vault;
    NFT _mockAuthNFTManager;
    NFT _mockAuthNFTAdmin;

    /// @notice Emitted when a question is created.
    event QuestionCreated(uint256 indexed questionId, address indexed creator);

    /// @notice Emitted when a challenge is created.
    event ChallengeCreated(uint256 indexed questionId, address indexed challengeCreator);

    /// @notice Emitted when a question is published.
    event QuestionPublished(uint256 indexed questionId, address indexed publisher);

    /// @notice Emitted when a question is claimed.
    event QuestionClaimed(uint256 indexed questionId, address indexed claimant);

    /// @notice Emitted when a question is answered.
    event QuestionAnswered(uint256 indexed questionId, address indexed answerer);

    /// @notice Emitted when a question is disqualified.
    event QuestionDisqualified(uint256 indexed questionId, address indexed disqualifier);

    /// @notice Emitted when a question is upvoted.
    event QuestionUpvoted(uint256 indexed questionId, address indexed voter);

    /// @notice Emitted when a question is unvoted.
    event QuestionUnvoted(uint256 indexed questionId, address indexed voter);

    function setUp() public {
        // Labeling
        vm.label(owner, "Owner");
        vm.label(other, "User");
        vm.label(manager, "Manager");

        vm.startPrank(owner);
        _mockAuthNFTManager = new NFT("Auth", "Auth");
        _mockAuthNFTAdmin = new NFT("Auth", "Auth");
        _metricToken = new MetricToken();
        _bountyQuestion = new BountyQuestion();
        _claimController = new ClaimController();
        _questionStateController = new QuestionStateController();
        _vault = new Vault(address(_metricToken), address(_questionStateController), treasury);
        _costController = new ActionCostController(address(_metricToken), address(_vault));
        _questionAPI = new QuestionAPI(
            address(_bountyQuestion),
            address(_questionStateController),
            address(_claimController),
            address(_costController)
        );

        _claimController.setQuestionApi(address(_questionAPI));
        _costController.setQuestionApi(address(_questionAPI));
        _questionStateController.setQuestionApi(address(_questionAPI));
        _bountyQuestion.setQuestionApi(address(_questionAPI));
        _vault.setCostController(address(_costController));
        _vault.setClaimController(address(_claimController));
        _vault.setBountyQuestion(address(_bountyQuestion));

        _metricToken.transfer(other, 100e18);
        _metricToken.transfer(other2, 100e18);
        _metricToken.transfer(other3, 100e18);

        _questionAPI.addHolderRole(PROGRAM_MANAGER_ROLE, address(_mockAuthNFTManager));
        _questionAPI.addHolderRole(ADMIN_ROLE, address(_mockAuthNFTAdmin));

        _mockAuthNFTManager.mintTo(manager);
        _mockAuthNFTAdmin.mintTo(other);

        vm.stopPrank();

        vm.prank(owner);
        _metricToken.approve(address(_vault), 100e18);

        vm.prank(manager);
        _metricToken.approve(address(_vault), 100e18);

        vm.prank(other);
        _metricToken.approve(address(_vault), 100e18);

        vm.prank(other2);
        _metricToken.approve(address(_vault), 100e18);

        vm.prank(other3);
        _metricToken.approve(address(_vault), 100e18);
    }

    // ---------------------- General tests ----------------------

    function test_CreateQuestionAndVoteForQuestionThenUnvoteForQuestion() public {
        console.log("Should correctly create a question and vote for it");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));

        // Vote for the question
        vm.stopPrank();
        vm.prank(other3);
        _questionAPI.upvoteQuestion(questionId);
        vm.startPrank(other);
        assertEq(_metricToken.balanceOf(other), 99e18);
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));
        assertEq(_questionStateController.getTotalVotes(questionId), 2);

        // Question is set for the right address and values
        _questionStateController.getVoters(questionId);

        // Unvote for the question
        vm.stopPrank();
        vm.prank(other3);
        _questionAPI.unvoteQuestion(questionId);

        // Check that accounting was done properly.
        _questionStateController.getVoters(questionId);
    }

    function test_UnvotingWithoutFirstHavingVotedDoesNotWork() public {
        console.log("It should not be possible to unvote if you have not voted for the question.");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));

        // Vote for the question
        vm.stopPrank();
        vm.prank(other3);
        _questionAPI.upvoteQuestion(questionId);
        vm.startPrank(other);
        assertEq(_metricToken.balanceOf(other), 99e18);
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));
        assertEq(_questionStateController.getTotalVotes(questionId), 2);

        // Question is set for the right address and values
        _questionStateController.getVoters(questionId);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectRevert(QuestionStateController.HasNotVotedForQuestion.selector);

        // Unvote for the question
        _questionAPI.unvoteQuestion(questionId);

        // Check that accounting was done properly.
        _questionStateController.getVoters(questionId);
        vm.stopPrank();
    }

    function test_CannotVoteSameQuestionMultipleTimes() public {
        console.log("It should not be possible to vote multiple times for the same question.");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));

        // Vote for the question
        vm.stopPrank();
        vm.prank(other3);
        _questionAPI.upvoteQuestion(questionId);
        vm.startPrank(other);
        assertEq(_metricToken.balanceOf(other), 99e18);
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));
        assertEq(_questionStateController.getTotalVotes(questionId), 2);

        // Question is set for the right address and values
        _questionStateController.getVoters(questionId);

        // Vote for the question again
        vm.stopPrank();
        vm.prank(other3);
        vm.expectRevert(QuestionStateController.HasAlreadyVotedForQuestion.selector);
        _questionAPI.upvoteQuestion(questionId);

        // Check that accounting was done properly.
        _questionStateController.getVoters(questionId);
    }

    function test_CannotVoteForOwnQuestion() public {
        console.log("It should not be possible to vote for your own question.");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));

        // Vote for the question
        vm.expectRevert(QuestionAPI.CannotVoteForOwnQuestion.selector);
        _questionAPI.upvoteQuestion(questionId);
        vm.stopPrank();
    }

    function test_VoteUnvoteVote() public {
        console.log("A user should be able to vote unvote vote.");

        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        vm.stopPrank();

        vm.startPrank(other2);
        _questionAPI.upvoteQuestion(questionId);

        _questionAPI.unvoteQuestion(questionId);

        _vault.withdrawMetric(questionId, STAGE.UNVOTE);

        _questionAPI.upvoteQuestion(questionId);
    }

    function test_CannotWithrawForUnvotingAfterCreatingQuestion() public {
        console.log("A user should not be able to withdraw their funds after creating a question.");

        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

        vm.expectRevert(Vault.CannotUnvoteOwnQuestion.selector);
        _vault.withdrawMetric(questionId, STAGE.UNVOTE);
        vm.stopPrank();
    }

    // ---------------------- Access control tests ----------------------
}
