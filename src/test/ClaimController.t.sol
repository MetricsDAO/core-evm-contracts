pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../contracts/Protocol/Vault.sol";
import "../contracts/MetricToken.sol";
import "@contracts/Protocol/QuestionAPI.sol";
import "@contracts/Protocol/ActionCostController.sol";
import "@contracts/Protocol/ClaimController.sol";
import "@contracts/Protocol/Vault.sol";
import {NFT} from "@contracts/Protocol/Extra/MockAuthNFT.sol";

contract claimControllerTest is Test {
    bytes32 public constant PROGRAM_MANAGER_ROLE = keccak256("PROGRAM_MANAGER_ROLE");

    // Accounts
    address owner = address(0x0a);
    address other = address(0x0b);
    address manager = address(0x0c);
    address treasury = address(0x4faFB87de15cFf7448bD0658112F4e4B0d53332c);

    uint256 questionId1;
    uint256 questionId2;
    uint256 questionId3;

    MetricToken _metricToken;
    Vault _vault;
    QuestionAPI _questionAPI;
    ClaimController _claimController;
    BountyQuestion _bountyQuestion;
    ActionCostController _costController;
    QuestionStateController _questionStateController;
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

        _mockAuthNFT.mintTo(manager);

        vm.stopPrank();

        //Approve Transfers
        vm.startPrank(address(_vault));
        _metricToken.approve(address(other), _metricToken.balanceOf(address(_vault)));
        _metricToken.approve(address(treasury), _metricToken.balanceOf(address(_vault)));
        vm.stopPrank();

        //Create questions
        vm.startPrank(other);
        // Create a question to be initialized
        _metricToken.approve(address(_vault), 200e18);
        questionId1 = _questionAPI.createQuestion("ipfs://XYZ", 25);
        questionId2 = _questionAPI.createQuestion("ipfs://XYZ", 15);
        questionId3 = _questionAPI.createQuestion("ipfs://XYZ", 0);

        // Publish questions
        _questionAPI.publishQuestion(questionId1);
        _questionAPI.publishQuestion(questionId2);
        vm.stopPrank();
    }

    // ---------------------- General functionality testing
    function test_initializeQuestion() public {
        console.log("Question should be initialized");

        vm.startPrank(other);
        //Check question initialization
        assertEq(_claimController.getClaimLimit(questionId1), 25);
        vm.stopPrank();
    }

    function test_initializeMultipleQuestions() public {
        console.log("It should initialize multiple questions");

        vm.startPrank(other);
        //Check question initialization
        assertEq(_claimController.getClaimLimit(questionId1), 25);
        assertEq(_claimController.getClaimLimit(questionId2), 15);
        vm.stopPrank();
    }

    function test_claim() public {
        console.log("owner should be able to claim");

        vm.startPrank(other);
        // Create a question to be initialized
        _metricToken.approve(address(_vault), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);

        // Publish question
        _questionAPI.publishQuestion(questionId);
        vm.stopPrank();

        vm.startPrank(owner);
        //Should this be called through _questionApi.claimQuestion()?
        _claimController.claim(questionId);
        address[] memory claims = _claimController.getClaims(questionId);
        assertEq(claims.length, 1);

        vm.stopPrank();
    }

    function test_canNotClaimTwice() public {
        console.log("owner should not be able to claim same question > 1x");
        vm.startPrank(owner);
        //TODO currently a question can be claimed > once
        //TODO claim should revert if user tries to claim again
        //claim question
        _claimController.claim(questionId1);
        //claim same question for second time
        _claimController.claim(questionId1);
        address[] memory claims = _claimController.getClaims(questionId1);
        assertEq(claims.length, 1);
        vm.stopPrank();
    }

    function test_claimLimit() public {
        console.log("claim limit can not be exceeded");
        vm.startPrank(owner);
        vm.expectRevert(ClaimController.ClaimLimitReached.selector);
        _claimController.claim(questionId3);
    }

    function test_answer() public {
        console.log("owner should be able to answer");
        vm.startPrank(owner);
        //TODO verify owner can't answer thier own question
        //TODO call from question API
        _claimController.claim(questionId1);
        _claimController.answer(questionId1, "ipfs://XYZ/answer");
        //_claimController.getAnswers(questionId1);
        vm.stopPrank();
    }

    function test_answerClaims() public {
        console.log("Should revert when question has not been claimed");
        vm.startPrank(owner);
        vm.expectRevert(ClaimController.NeedClaimToAnswer.selector);
        _claimController.answer(questionId1, "ipfs://XYZ/answer");
        vm.stopPrank();
    }
}
