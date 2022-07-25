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

contract vaultTest is Test {
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

    function test_lockMetric() public {
        console.log("Should lock Metric.");

        vm.startPrank(other);
        // Create a question and see that it is created and balance is updated.
        _metricToken.approve(address(_vault), 100e18);
        _questionAPI.createQuestion("ipfs://XYZ", 25);
        assertEq(_vault.getMetricTotalLockedBalance(), 100e16);
        vm.stopPrank();
    }

    function test_lockMetricForSecondQuestion() public {
        //Test additional deposit
        console.log("Should have double the locked Metric with second deposit.");
        vm.startPrank(other);
        // Create 1st question
        _metricToken.approve(address(_vault), 100e18);
        _questionAPI.createQuestion("ipfs://XYZ", 25);
        // Create 2nd question
        _metricToken.approve(address(_vault), 100e18);
        _questionAPI.createQuestion("ipfs://XYZ/1", 26);
        assertEq(_vault.getMetricTotalLockedBalance(), 200e16);
        vm.stopPrank();
    }

    function test_withdrawMetric() public {
        console.log("Should withdraw Metric");
        vm.startPrank(other);
        // Create question
        _metricToken.approve(address(_vault), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);
        //withdraw Metric
        _vault.withdrawMetric(other, questionId);
        assertEq(_vault.getMetricTotalLockedBalance(), 0);
        vm.stopPrank();
    }

    function test_slashMetric() public {
        console.log("Should slash question when appropriate");
        vm.startPrank(other);
        // Create question
        _metricToken.approve(address(_vault), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);
        vm.stopPrank();
        //approve Metric transfer for vault
        vm.startPrank(address(_vault));
        _metricToken.approve(address(other), _metricToken.balanceOf(address(_vault)));
        _metricToken.approve(address(treasury), _metricToken.balanceOf(address(_vault)));
        vm.stopPrank();
        //slash Metric
        vm.startPrank(owner);
        _vault.slashMetric(other, questionId);
        vm.stopPrank();
        //check user Metric balance
        //assertEq(_metricToken.balanceOf(other), 0.5e18);
        //check treasury Metric balance
        //assertEq(_metricToken.balanceOf(other), 0.5e18);
    }
}
