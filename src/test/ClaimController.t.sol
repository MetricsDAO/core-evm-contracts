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
    }

    // ---------------------- General functionality testing
    function test_initializeQuestion() public {
        console.log("Question should be initialized");

        vm.startPrank(other);
        // Create a question to be initialized
        _metricToken.approve(address(_vault), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);

        // Publish question
        _questionAPI.publishQuestion(questionId);

        //Check question initialization
        assertEq(_claimController.getClaimLimit(questionId), 25);
        vm.stopPrank();
    }
}
