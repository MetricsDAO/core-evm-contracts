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

import "../contracts/Protocol/Enums/ActionEnum.sol";
import "../contracts/Protocol/Enums/VaultEnum.sol";
import "../contracts/Protocol/Enums/QuestionStateEnum.sol";

contract QuestionAPITest is Test {
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

    // ---------------------- General functionality testing

    function test_InitialMint() public {
        console.log("Should correctly distribute initial mint");
        assertEq(_metricToken.balanceOf(owner), 1000000000e18 - 300e18);
    }

    function test_CreateTwoQuestionsWithChangingActionCost() public {
        console.log("Should correctly create 2 questions and do proper accounting.");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        uint256 questionIdOne = _questionAPI.createQuestion("ipfs://XYZ", 25);
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionIdOne)), uint256(STATE.VOTING));
        assertEq(_claimController.getClaimLimit(questionIdOne), 25);

        vm.stopPrank();

        // Update the costs of creating a question
        vm.prank(owner);
        _costController.setActionCost(ACTION.CREATE, 9e18);

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 99e18);
        uint256 questionIdTwo = _questionAPI.createQuestion("ipfs://MDAO", 15);
        assertEq(_metricToken.balanceOf(other), 90e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionIdTwo)), uint256(STATE.VOTING));
        assertEq(_claimController.getClaimLimit(questionIdTwo), 15);

        // Assert that accounting has been done correctly
        assertEq(_vault.getLockedPerUser(other), 10e18);

        vm.stopPrank();
    }

    function test_CreateQuestion() public {
        console.log("Should correctly create a question");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));
        assertEq(_claimController.getClaimLimit(questionId), 25);

        // Other cannot directly call onlyApi functions
        vm.expectRevert(OnlyApi.NotTheApi.selector);
        _costController.payForAction(other, questionId, ACTION.CREATE);

        vm.stopPrank();
    }

    function test_CreateQuestionAndVoteForQuestionThenUnvoteForQuestion() public {
        console.log("Should correctly create a question and vote for it");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));
        assertEq(_claimController.getClaimLimit(questionId), 25);

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
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));
        assertEq(_claimController.getClaimLimit(questionId), 25);

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
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));
        assertEq(_claimController.getClaimLimit(questionId), 25);

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
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));
        assertEq(_claimController.getClaimLimit(questionId), 25);

        // Vote for the question
        vm.expectRevert(QuestionAPI.CannotVoteForOwnQuestion.selector);
        _questionAPI.upvoteQuestion(questionId);
        vm.stopPrank();
    }

    function test_DisqualifyQuestion() public {
        vm.startPrank(owner);
        uint256 badQuestion = _questionAPI.createQuestion("Bad question", 1);
        _questionAPI.disqualifyQuestion(badQuestion);
        uint256 questionState = uint256(_questionStateController.getState(badQuestion));

        assertEq(questionState, uint256(STATE.DISQUALIFIED));
        vm.stopPrank();
    }

    function test_DisqualifyQuestionTwo() public {
        vm.startPrank(other);
        uint256 badQuestion = _questionAPI.createQuestion("Bad question", 1);
        vm.stopPrank();

        vm.prank(owner);
        _questionAPI.disqualifyQuestion(badQuestion);

        assertEq(uint256(_questionStateController.getState(badQuestion)), uint256(STATE.DISQUALIFIED));
    }

    function test_ProgramManagerCreateChallenge() public {
        console.log("Only a user with the ProgramManager role should be allowed to create a challenge.");

        // Check that the manager holds the nft
        assertEq(_mockAuthNFTManager.ownerOf(1), manager);

        // Create a challenge from the manager
        vm.prank(manager);
        uint256 questionId = _questionAPI.createChallenge("ipfs://XYZ", 25);

        // Verify that challenge is published
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.PUBLISHED));

        // Make sure we cannot vote for the challenge
        vm.prank(other);
        vm.expectRevert(QuestionStateController.InvalidStateTransition.selector);
        _questionAPI.upvoteQuestion(questionId);

        // Make sure that not any user can create a challenge
        vm.prank(other);
        vm.expectRevert(NFTLocked.DoesNotHold.selector);
        _questionAPI.createChallenge("ipfs://XYZ", 25);
    }

    function test_ClaimQuestion() public {
        console.log("A user should should be able to claim a challenge.");

        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);

        // Publish the question
        _questionAPI.publishQuestion(questionId);

        // Claim the question
        _questionAPI.claimQuestion(questionId);

        // Verify the right user has claimed the question
        assertEq(_claimController.getClaims(questionId)[0], other);
        vm.stopPrank();
    }

    function test_CannotClaimQuestionThatIsNotPublished() public {
        console.log("A user shouldnt be able to claim an unpublished question");

        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);

        // Attempt claim
        vm.expectRevert(QuestionAPI.ClaimsNotOpen.selector);
        _questionAPI.claimQuestion(questionId);
        vm.stopPrank();
    }

    function test_CannotClaimMoreThanTheClaimLimit() public {
        console.log("A user shouldnt be able to claim a question that has reached its limit");

        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 1);

        // Publish the question
        _questionAPI.publishQuestion(questionId);

        // Attempt claim
        _questionAPI.claimQuestion(questionId);

        vm.stopPrank();

        vm.startPrank(other2);

        // Attempt claim again
        vm.expectRevert(ClaimController.ClaimLimitReached.selector);
        _questionAPI.claimQuestion(questionId);
    }

    function test_UserCannotClaimQuestionMultipleTimes() public {
        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 5);

        // Publish the question
        _questionAPI.publishQuestion(questionId);

        // Claim the question
        _questionAPI.claimQuestion(questionId);

        // Same user tries to claim again
        vm.expectRevert(ClaimController.AlreadyClaimed.selector);
        _questionAPI.claimQuestion(questionId);

        vm.stopPrank();
    }

    function test_verifyClaimingAccounting() public {
        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 5);

        // Publish the question
        _questionAPI.publishQuestion(questionId);

        // Verify that everything is updated correctly
        _claimController.getClaimDataForUser(questionId, other);

        // Claim the question
        _questionAPI.claimQuestion(questionId);

        // Verify that everything is updated correctly
        _claimController.getClaimDataForUser(questionId, other);

        vm.stopPrank();

        vm.startPrank(other2);

        _claimController.getClaimDataForUser(questionId, other2);
        _questionAPI.claimQuestion(questionId);

        // Verify that everything is updated correctly
        _claimController.getClaimDataForUser(questionId, other2);
    }

    function test_VerifyEventsEmitted() public {
        console.log("All events should be emitted correctly.");

        vm.startPrank(other);

        // Create a question
        vm.expectEmit(true, true, false, true);
        emit QuestionCreated(1, address(other));
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 5);

        vm.stopPrank();

        vm.startPrank(other2);
        // Upvote a question
        vm.expectEmit(true, true, false, false);
        emit QuestionUpvoted(1, address(other2));
        _questionAPI.upvoteQuestion(questionId);

        // Unvote a question
        vm.expectEmit(true, true, false, false);
        emit QuestionUnvoted(1, address(other2));
        _questionAPI.unvoteQuestion(questionId);
        vm.stopPrank();

        vm.startPrank(other);
        // Publish the question
        vm.expectEmit(true, true, false, false);
        emit QuestionPublished(questionId, address(other));
        _questionAPI.publishQuestion(questionId);

        // Claim the question
        vm.expectEmit(true, true, false, false);
        emit QuestionClaimed(questionId, address(other));
        _questionAPI.claimQuestion(questionId);

        // Question answered
        vm.stopPrank();

        // Create challenge
        vm.expectEmit(true, true, false, false);
        emit ChallengeCreated(2, address(manager));
        vm.prank(manager);
        _questionAPI.createChallenge("ipfs://XYZ", 5);

        // Disqualify question
        vm.expectEmit(true, false, false, false);
        emit QuestionDisqualified(questionId, address(owner));
        vm.prank(owner);
        _questionAPI.disqualifyQuestion(questionId);
    }

    function test_FunctionLock() public {
        console.log("All locked functions should be locked.");

        vm.prank(owner);
        _questionAPI.toggleLock();

        vm.startPrank(other);
        uint256 q = _questionAPI.createQuestion("ipfs://XYZ", 5);

        vm.expectRevert(FunctionLocked.FunctionIsLocked.selector);
        _questionAPI.publishQuestion(q);

        vm.stopPrank();
    }

    function test_OnlyAdminCanPublishQuestion() public {
        console.log("Only the admin should be able to publish a question.");

        vm.prank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 5);
        vm.prank(owner);
        _questionAPI.toggleLock();

        // Attempt to publish the question
        vm.prank(other2);
        vm.expectRevert(NFTLocked.DoesNotHold.selector);
        _questionAPI.publishQuestion(questionId);

        vm.prank(other);
        vm.expectRevert(FunctionLocked.FunctionIsLocked.selector);

        _questionAPI.publishQuestion(questionId);
    }

    function test_OnlyOwnerCanMintPermissionedNFTs() public {
        console.log("Only the owner should be able to mint permissioned NFTs.");

        vm.prank(other);
        vm.expectRevert("Ownable: caller is not the owner");
        _questionAPI.addHolderRole(ADMIN_ROLE, address(0));
    }

    function test_WithdrawAfterUnvoting() public {
        console.log("A user should be able to withdraw their funds after unvoting.");

        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 5);
        vm.stopPrank();

        vm.startPrank(other2);

        // Vote for the question
        _questionAPI.upvoteQuestion(questionId);
        assertEq(_metricToken.balanceOf(other2), 99e18);

        // Unvote the question
        _questionAPI.unvoteQuestion(questionId);

        // Verify balance updates
        _vault.withdrawMetric(questionId, STAGE.UNVOTE);

        assertEq(_metricToken.balanceOf(other2), 100e18);
        vm.stopPrank();

        vm.startPrank(other3);
        // Vote for the question
        _questionAPI.upvoteQuestion(questionId);
        assertEq(_metricToken.balanceOf(other3), 99e18);

        // Verify user cannot withdraw funds
        vm.expectRevert(Vault.UserHasNotUnvoted.selector);
        _vault.withdrawMetric(questionId, STAGE.UNVOTE);

        vm.stopPrank();
    }

    // --------------------- Testing for access controlls
}
