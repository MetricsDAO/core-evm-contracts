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

    function test_InitialMint() public {
        console.log("Should correctly distribute initial mint");
        assertEq(_metricToken.balanceOf(owner), 1000000000e18 - 300e18);
    }

    function test_CreateQuestion() public {
        console.log("Should correctly create a question");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        assertEq(_metricToken.balanceOf(other), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        assertEq(_metricToken.balanceOf(other), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(uint256(_questionStateController.getState(questionId)), uint256(STATE.VOTING));

        // Other cannot directly call onlyApi functions
        vm.expectRevert(OnlyApi.NotTheApi.selector);
        _costController.payForAction(other, questionId, ACTION.CREATE);

        vm.stopPrank();
    }

    function test_DisqualifyQuestion() public {
        vm.startPrank(owner);
        uint256 badQuestion = _questionAPI.createQuestion("ipfs://XYZ");
        _questionAPI.disqualifyQuestion(badQuestion);
        uint256 questionState = uint256(_questionStateController.getState(badQuestion));

        assertEq(questionState, uint256(STATE.DISQUALIFIED));
        vm.stopPrank();
    }

    function test_DisqualifyQuestionTwo() public {
        vm.startPrank(other);
        uint256 badQuestion = _questionAPI.createQuestion("ipfs://XYZ");
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

    function test_VerifyEventsEmitted() public {
        console.log("All events should be emitted correctly.");

        vm.startPrank(other);

        // Create a question
        vm.expectEmit(true, true, false, true);
        emit QuestionCreated(1, address(other));
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

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
        _questionAPI.publishQuestion(questionId, 25);

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

    // ---------------------- Access control tests ----------------------
    function test_OnlyAdminCanPublishQuestion() public {
        console.log("Only the admin should be able to publish a question.");

        vm.prank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        vm.prank(owner);
        _questionAPI.toggleLock();

        // Attempt to publish the question
        vm.prank(other2);
        vm.expectRevert(NFTLocked.DoesNotHold.selector);
        _questionAPI.publishQuestion(questionId, 25);

        vm.prank(other);
        _questionAPI.publishQuestion(questionId, 25);
    }

    function test_OnlyOwnerCanMintPermissionedNFTs() public {
        console.log("Only the owner should be able to mint permissioned NFTs.");

        vm.prank(other);
        vm.expectRevert("Ownable: caller is not the owner");
        _questionAPI.addHolderRole(ADMIN_ROLE, address(0));
    }

    function test_OnlyManagerCanDirectlyCreateChallenge() public {
        console.log("Only the manager should be able to directly create a challenge.");

        vm.prank(other);
        vm.expectRevert(NFTLocked.DoesNotHold.selector);
        _questionAPI.createChallenge("ipfs://XYZ", 5);
    }

    function test_FunctionLock() public {
        console.log("All locked functions should be locked.");

        vm.prank(owner);
        _questionAPI.toggleLock();

        vm.startPrank(other);
        uint256 q = _questionAPI.createQuestion("ipfs://XYZ");
        _questionAPI.publishQuestion(q, 25);

        vm.expectRevert(FunctionLocked.FunctionIsLocked.selector);
        _questionAPI.answerQuestion(q, "ipfs://XYZ");

        vm.stopPrank();
    }
}
