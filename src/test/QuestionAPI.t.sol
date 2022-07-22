// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "@contracts/MetricToken.sol";
import "@contracts/Protocol/QuestionAPI.sol";
import "@contracts/Protocol/ClaimController.sol";
import "@contracts/Protocol/QuestionStateController.sol";
import "@contracts/Protocol/BountyQuestion.sol";
import "@contracts/Protocol/ActionCostController.sol";
import {NFT} from "@contracts/Protocol/Extra/MockAuthNFT.sol";

contract QuestionAPITest is Test {
    // Roles
    bytes32 public constant PROGRAM_MANAGER_ROLE = keccak256("PROGRAM_MANAGER_ROLE");

    // Accounts
    address owner = address(0x0a);
    address other = address(0x0b);
    address manager = address(0x0c);

    MetricToken _metricToken;
    QuestionAPI _questionAPI;
    BountyQuestion _bountyQuestion;
    ClaimController _claimController;
    ActionCostController _costController;
    QuestionStateController _questionStateController;
    Vault _vault;
    NFT _mockAuthNFT;

    function setUp() public {
        // Labeling
        vm.label(owner, "Owner");
        vm.label(other, "User");
        vm.label(manager, "Manager");

        vm.startPrank(owner);
        _mockAuthNFT = new NFT("Auth", "Auth");
        _metricToken = new MetricToken();
        _bountyQuestion = new BountyQuestion();
        _claimController = new ClaimController();
        _questionStateController = new QuestionStateController();
        _vault = new Vault(address(_metricToken), address(_questionStateController));
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

        _metricToken.transfer(other, 100e18);

        _mockAuthNFT.mintTo(manager);

        vm.stopPrank();
    }

    // ---------------------- General functionality testing

    function test_InitialMint() public {
        console.log("Should correctly distribute initial mint");
        assertEq(_metricToken.balanceOf(owner), 1000000000e18 - 100e18);
    }

    function test_CreateTwoQuestionsWithChangingActionCost() public {
        console.log("Should correctly create 2 questions and do proper accounting.");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        _metricToken.approve(address(_costController), 100e18);
        uint256 questionIdOne = _questionAPI.createQuestion("ipfs://XYZ", 25);
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(_questionStateController.getState(questionIdOne), uint256(IQuestionStateController.STATE.VOTING));
        assertEq(_claimController.getClaimLimit(questionIdOne), 25);

        vm.stopPrank();

        // Update the costs of creating a question
        vm.prank(owner);
        _costController.setCreateCost(9e18);

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 99e18);
        uint256 questionIdTwo = _questionAPI.createQuestion("ipfs://MDAO", 15);
        assertEq(_metricToken.balanceOf(other), 90e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(_questionStateController.getState(questionIdTwo), uint256(IQuestionStateController.STATE.VOTING));
        assertEq(_claimController.getClaimLimit(questionIdTwo), 15);

        // Assert that accounting has been done correctly
        assertEq(_costController.getLockedPerUser(other), 10e18);

        vm.stopPrank();
    }

    function test_CreateQuestion() public {
        console.log("Should correctly create a question");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        _metricToken.approve(address(_costController), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(_questionStateController.getState(questionId), uint256(IQuestionStateController.STATE.VOTING));
        assertEq(_claimController.getClaimLimit(questionId), 25);

        // Other cannot directly call onlyApi functions
        vm.expectRevert(OnlyApi.NotTheApi.selector);
        _costController.payForCreateQuestion(other);

        vm.stopPrank();
    }

    function test_CreateQuestionAndVoteForQuestionThenUnvoteForQuestion() public {
        console.log("Should correctly create a question and vote for it");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        _metricToken.approve(address(_costController), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(_questionStateController.getState(questionId), uint256(IQuestionStateController.STATE.VOTING));
        assertEq(_claimController.getClaimLimit(questionId), 25);

        // Vote for the question
        _questionAPI.upvoteQuestion(questionId, 5e18);
        assertEq(_metricToken.balanceOf(other), 99e18);
        assertEq(_questionStateController.getState(questionId), uint256(IQuestionStateController.STATE.VOTING));
        assertEq(_questionStateController.getTotalVotes(questionId), 5e18);

        // Question is set for the right address and values
        _questionStateController.getVotes(questionId);

        // Unvote for the question
        _questionAPI.unvoteQuestion(questionId);

        // Check that accounting was done properly.
        _questionStateController.getVotes(questionId);
        vm.stopPrank();
    }

    function test_UnvotingWithoutFirstHavingVotedDoesNotWork() public {
        console.log("It should not be possible to unvote if you have not voted for the question.");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        _metricToken.approve(address(_costController), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(_questionStateController.getState(questionId), uint256(IQuestionStateController.STATE.VOTING));
        assertEq(_claimController.getClaimLimit(questionId), 25);

        // Vote for the question
        _questionAPI.upvoteQuestion(questionId, 5e18);
        assertEq(_metricToken.balanceOf(other), 99e18);
        assertEq(_questionStateController.getState(questionId), uint256(IQuestionStateController.STATE.VOTING));
        assertEq(_questionStateController.getTotalVotes(questionId), 5e18);

        // Question is set for the right address and values
        _questionStateController.getVotes(questionId);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectRevert(QuestionStateController.HasNotVotedForQuestion.selector);

        // Unvote for the question
        _questionAPI.unvoteQuestion(questionId);

        // Check that accounting was done properly.
        _questionStateController.getVotes(questionId);
        vm.stopPrank();
    }

    function test_CannotVoteSameQuestionMultipleTimes() public {
        console.log("It should not be possible to vote multiple times for the same question.");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        _metricToken.approve(address(_costController), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(_questionStateController.getState(questionId), uint256(IQuestionStateController.STATE.VOTING));
        assertEq(_claimController.getClaimLimit(questionId), 25);

        // Vote for the question
        _questionAPI.upvoteQuestion(questionId, 5e18);
        assertEq(_metricToken.balanceOf(other), 99e18);
        assertEq(_questionStateController.getState(questionId), uint256(IQuestionStateController.STATE.VOTING));
        assertEq(_questionStateController.getTotalVotes(questionId), 5e18);

        // Question is set for the right address and values
        _questionStateController.getVotes(questionId);

        // Vote for the question again
        vm.expectRevert(QuestionStateController.HasAlreadyVotedForQuestion.selector);
        _questionAPI.upvoteQuestion(questionId, 5e18);

        // Check that accounting was done properly.
        _questionStateController.getVotes(questionId);
        vm.stopPrank();
    }

    function test_DisqualifyQuestion() public {
        vm.startPrank(owner);
        _metricToken.approve(address(_costController), 100e18);
        uint256 badQuestion = _questionAPI.createQuestion("Bad question", 1);
        _questionAPI.disqualifyQuestion(badQuestion);
        uint256 questionState = _questionStateController.getState(badQuestion);

        assertEq(questionState, 6);
        vm.stopPrank();
    }

    function test_DisqualifyQuestionTwo() public {
        vm.startPrank(other);
        _metricToken.approve(address(_costController), 100e18);
        uint256 badQuestion = _questionAPI.createQuestion("Bad question", 1);
        vm.stopPrank();

        vm.prank(owner);
        _questionAPI.disqualifyQuestion(badQuestion);

        assertEq(_questionStateController.getState(badQuestion), uint256(IQuestionStateController.STATE.BAD));
    }

    function test_ProgramManagerCreateChallenge() public {
        console.log("Only a user with the ProgramManager role should be allowed to create a challenge.");

        // Check that the manager holds the nft
        assertEq(_mockAuthNFT.ownerOf(1), manager);

        // Create a program manager role tied to the mockAuthNFT.
        // This means that anyone holding a token of mockAuthNFT has program_manager_role permissions
        vm.prank(owner);
        _questionAPI.addHolderRole(PROGRAM_MANAGER_ROLE, address(_mockAuthNFT));

        // Create a challenge from the manager
        vm.prank(manager);
        uint256 questionId = _questionAPI.createChallenge("ipfs://XYZ", 25);

        // Verify that challenge is published
        assertEq(_questionStateController.getState(questionId), uint256(IQuestionStateController.STATE.PUBLISHED));

        // Make sure we cannot vote for the challenge
        vm.prank(other);
        vm.expectRevert(QuestionStateController.InvalidStateTransition.selector);
        _questionAPI.upvoteQuestion(questionId, 5e18);

        // Make sure that not any user can create a challenge
        vm.prank(other);
        vm.expectRevert(NFTLocked.DoesNotHold.selector);
        _questionAPI.createChallenge("ipfs://XYZ", 25);
    }

    // --------------------- Testing for access controlls
}
