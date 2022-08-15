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

    function test_CannotClaimQuestionThatIsNotPublished() public {
        console.log("A user shouldnt be able to claim an unpublished question");

        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

        // Attempt claim
        vm.expectRevert(QuestionAPI.ClaimsNotOpen.selector);
        _questionAPI.claimQuestion(questionId);
        vm.stopPrank();
    }

    function test_CannotClaimMoreThanTheClaimLimit() public {
        console.log("A user shouldnt be able to claim a question that has reached its limit");

        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

        // Publish the question
        _questionAPI.publishQuestion(questionId, 1);

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
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

        // Publish the question
        _questionAPI.publishQuestion(questionId, 25);

        // Claim the question
        _questionAPI.claimQuestion(questionId);

        // Same user tries to claim again
        vm.expectRevert(ClaimController.AlreadyClaimed.selector);
        _questionAPI.claimQuestion(questionId);

        vm.stopPrank();
    }

    function test_verifyClaimingAccounting() public {
        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

        // Publish the question
        _questionAPI.publishQuestion(questionId, 25);

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

    function test_ClaimReleaseClaim() public {
        console.log("A user should be able to release their claim after claiming.");

        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        _questionAPI.publishQuestion(questionId, 25);
        vm.stopPrank();

        vm.startPrank(other2);
        assertEq(_metricToken.balanceOf(other2), 100e18);

        // Claim the question
        _questionAPI.claimQuestion(questionId);
        assertEq(uint256(_claimController.getQuestionClaimState(questionId, other2)), uint256(CLAIM_STATE.CLAIMED));
        assertEq(_metricToken.balanceOf(other2), 99e18);

        // Release the claim
        _questionAPI.releaseClaim(questionId);
        assertEq(uint256(_claimController.getQuestionClaimState(questionId, other2)), uint256(CLAIM_STATE.RELEASED));

        _vault.withdrawMetric(questionId, STAGE.RELEASE_CLAIM);
        assertEq(_metricToken.balanceOf(other2), 100e18);

        _questionAPI.claimQuestion(questionId);
        assertEq(uint256(_claimController.getQuestionClaimState(questionId, other2)), uint256(CLAIM_STATE.CLAIMED));
        assertEq(_metricToken.balanceOf(other2), 99e18);

        vm.stopPrank();
    }

    function test_ClaimTryWithdrawWithoutRelease() public {
        console.log("A user should only be able to try to withdraw their claim after releasing.");

        vm.startPrank(other);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
        _questionAPI.publishQuestion(questionId, 25);
        vm.stopPrank();

        vm.startPrank(other2);
        assertEq(_metricToken.balanceOf(other2), 100e18);

        // Claim the question
        _questionAPI.claimQuestion(questionId);
        assertEq(uint256(_claimController.getQuestionClaimState(questionId, other2)), uint256(CLAIM_STATE.CLAIMED));
        assertEq(_metricToken.balanceOf(other2), 99e18);

        vm.expectRevert(Vault.ClaimNotReleased.selector);
        _vault.withdrawMetric(questionId, STAGE.RELEASE_CLAIM);

        vm.stopPrank();
    }

    // ---------------------- Access control tests ----------------------
}
