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

import "../contracts/Protocol/Enums/VaultEnum.sol";

contract vaultTest is Test {
    bytes32 public constant PROGRAM_MANAGER_ROLE = keccak256("PROGRAM_MANAGER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Accounts
    address owner = address(0x0a);
    address other = address(0x0b);
    address other2 = address(0x0d);
    address other3 = address(0x0e);
    address manager = address(0x0c);
    address treasury = address(0x4faFB87de15cFf7448bD0658112F4e4B0d53332c);

    MetricToken _metricToken;
    Vault _vault;
    QuestionAPI _questionAPI;
    ClaimController _claimController;
    BountyQuestion _bountyQuestion;
    ActionCostController _costController;
    QuestionStateController _questionStateController;
    NFT _mockAuthNFTManager;
    NFT _mockAuthNFTAdmin;

    function setUp() public {
        // Labeling
        vm.label(owner, "Owner");
        vm.label(other, "User");
        vm.label(other2, "User 2");
        vm.label(other3, "User 3");
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

        _mockAuthNFTAdmin.mintTo(owner);
        _mockAuthNFTManager.mintTo(manager);
        _mockAuthNFTAdmin.mintTo(other);

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
        _questionAPI.createQuestion("ipfs://XYZ");
        assertEq(_vault.getMetricTotalLockedBalance(), 100e16);
        vm.stopPrank();
    }

    function test_lockMetricForSecondQuestion() public {
        console.log("Should have double the locked Metric with second deposit.");

        vm.startPrank(other);
        // Create 1st question
        _metricToken.approve(address(_vault), 100e18);
        _questionAPI.createQuestion("ipfs://XYZ");

        // Create 2nd question
        _questionAPI.createQuestion("ipfs://XYZ");
        assertEq(_vault.getMetricTotalLockedBalance(), 200e16);

        vm.stopPrank();
    }

    function test_withdrawMetric() public {
        console.log("Should withdraw Metric");
        vm.startPrank(other);

        // Create question
        _metricToken.approve(address(_vault), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

        // Publish question
        _questionAPI.publishQuestion(questionId, 25);

        //withdraw Metric
        _vault.withdrawMetric(questionId, STAGE.CREATE_AND_VOTE);
        assertEq(_vault.getMetricTotalLockedBalance(), 0);
        vm.stopPrank();
    }

    // function test_slashMetric() public {
    //     console.log("Should slash question when appropriate");
    //     vm.startPrank(other);
    //     // Create question
    //     _metricToken.approve(address(_vault), 100e18);
    //     uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
    //     vm.stopPrank();

    //     //slash Metric
    //     vm.startPrank(owner);
    //     _vault.slashMetric(questionId);
    //     vm.stopPrank();

    //     // Check that Metric is slashed
    //     assertEq(_metricToken.balanceOf(other), 99.5e18);
    //     // Check treasury Metric balance
    //     assertEq(_metricToken.balanceOf(treasury), 0.5e18);
    // }

    // // ---------------------- Access control testing
    // function test_onlyOwnerCanSlashMetric() public {
    //     console.log("Only owner should be able to slash a question");

    //     vm.startPrank(other);
    //     // Create question
    //     _metricToken.approve(address(_vault), 100e18);
    //     uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

    //     //slash Metric
    //     vm.expectRevert("Ownable: caller is not the owner");
    //     _vault.slashMetric(questionId);
    //     vm.stopPrank();
    // }

    // function test_cannotSlashSameQuestionTwice() public {
    //     console.log("We can only slash a question once.");

    //     vm.startPrank(other);
    //     // Create question
    //     _metricToken.approve(address(_vault), 100e18);
    //     uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");
    //     vm.stopPrank();

    //     vm.startPrank(owner);
    //     // Slash
    //     _vault.slashMetric(questionId);

    //     // Slash again
    //     vm.expectRevert(Vault.AlreadySlashed.selector);
    //     _vault.slashMetric(questionId);
    //     vm.stopPrank();
    // }

    function test_onlyOwnerCanSetSensitiveAddresses() public {
        console.log("Only owner should be able to set sensitive addresses");

        vm.startPrank(other);
        // Attempt to set sensitive addresses
        vm.expectRevert("Ownable: caller is not the owner");
        _vault.setQuestionStateController(address(0x1));

        vm.expectRevert("Ownable: caller is not the owner");
        _vault.setTreasury(address(0x1));

        vm.expectRevert("Ownable: caller is not the owner");
        _vault.setMetric(address(0x1));
        vm.stopPrank();

        vm.stopPrank();

        vm.startPrank(owner);
        _vault.setQuestionStateController(address(0x1));
        _vault.setTreasury(address(0x1));
        _vault.setMetric(address(0x1));

        assertEq(address(_vault.questionStateController()), address(0x1));
        assertEq(_vault.treasury(), address(0x1));
        assertEq(address(_vault.metric()), address(0x1));
    }

    function test_sensitiveAddressesCannotBeSetToNullAddress() public {
        console.log("Sensitive addresses cannot be set to null.");

        vm.startPrank(owner);
        vm.expectRevert(Vault.InvalidAddress.selector);
        _vault.setQuestionStateController(address(0x0));

        // This should be allowed as at some point the treasury might wannt to burn tokens or something.
        _vault.setTreasury(address(0x0));

        vm.expectRevert(Vault.InvalidAddress.selector);
        _vault.setMetric(address(0x0));
        vm.stopPrank();
    }

    function test_cannotWithdrawUnpublishedQuestion() public {
        console.log("Should not withdraw Metric");
        vm.startPrank(other);

        // Create question
        _metricToken.approve(address(_vault), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

        //withdraw Metric
        vm.expectRevert(Vault.QuestionNotPublished.selector);
        _vault.withdrawMetric(questionId, STAGE.CREATE_AND_VOTE);
        vm.stopPrank();
    }

    function test_cannotWithdrawSameQuestionTwice() public {
        console.log("Should not withdraw Metric twice");
        vm.startPrank(other);

        // Create question
        _metricToken.approve(address(_vault), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ");

        // Publish question
        _questionAPI.publishQuestion(questionId, 25);

        // Withdraw Metric
        _vault.withdrawMetric(questionId, STAGE.CREATE_AND_VOTE);

        // Withdraw again
        vm.expectRevert(Vault.NoMetricDeposited.selector);
        _vault.withdrawMetric(questionId, STAGE.CREATE_AND_VOTE);

        vm.stopPrank();
    }

    function test_StageVaultAccountingIsCorrect() public {
        console.log("Stage Vault Accounting is correct");
        vm.startPrank(other);

        // Create question
        _metricToken.approve(address(_vault), 100e18);
        uint256 questionIdOne = _questionAPI.createQuestion("ipfs://XYZ");

        // Verify total vault balance is correct
        assertEq(_vault.getMetricTotalLockedBalance(), 1e18);

        // Verify that question vault balance is correct
        assertEq(_vault.getLockedMetricByQuestion(questionIdOne), 1e18);

        // Verify that the right properties are set on the question
        assertEq(_vault.getUserFromProperties(questionIdOne, STAGE.CREATE_AND_VOTE, other), other);
        assertEq(_vault.getAmountFromProperties(questionIdOne, STAGE.CREATE_AND_VOTE, other), 1e18);

        // Verify that other stages arent updated
        assertEq(_vault.getUserFromProperties(questionIdOne, STAGE.CLAIM_AND_ANSWER, other), address(0x0));
        assertEq(_vault.getUserFromProperties(questionIdOne, STAGE.REVIEW, other), address(0x0));

        assertEq(_vault.getAmountFromProperties(questionIdOne, STAGE.CLAIM_AND_ANSWER, other), 0);
        assertEq(_vault.getAmountFromProperties(questionIdOne, STAGE.REVIEW, other), 0);
        vm.stopPrank();

        // Repeat the same for second user
        vm.startPrank(other2);

        // Create question
        _metricToken.approve(address(_vault), 100e18);
        uint256 questionIdTwo = _questionAPI.createQuestion("ipfs://XYZ");

        // Verify total vault balance is correct
        assertEq(_vault.getMetricTotalLockedBalance(), 2e18);

        // Verify that question vault balance is correct
        assertEq(_vault.getLockedMetricByQuestion(questionIdTwo), 1e18);

        // Verify that the right properties are set on the question
        assertEq(_vault.getUserFromProperties(questionIdTwo, STAGE.CREATE_AND_VOTE, other2), other2);
        assertEq(_vault.getAmountFromProperties(questionIdTwo, STAGE.CREATE_AND_VOTE, other2), 1e18);

        // Verify that other stages arent updated
        assertEq(_vault.getUserFromProperties(questionIdTwo, STAGE.CLAIM_AND_ANSWER, other2), address(0x0));
        assertEq(_vault.getUserFromProperties(questionIdTwo, STAGE.REVIEW, other2), address(0x0));

        assertEq(_vault.getAmountFromProperties(questionIdTwo, STAGE.CLAIM_AND_ANSWER, other2), 0);
        assertEq(_vault.getAmountFromProperties(questionIdTwo, STAGE.REVIEW, other2), 0);
        vm.stopPrank();
        vm.stopPrank();

        // Introduce a voter
        vm.startPrank(other3);

        _metricToken.approve(address(_vault), 100e18);

        _questionAPI.upvoteQuestion(questionIdOne);
        _questionAPI.upvoteQuestion(questionIdTwo);

        // Verify that total vault balance is updated
        assertEq(_vault.getMetricTotalLockedBalance(), 4e18);

        // Verify that question vault balance is correct
        assertEq(_vault.getLockedMetricByQuestion(questionIdOne), 2e18);
        assertEq(_vault.getLockedMetricByQuestion(questionIdTwo), 2e18);

        // Verify that the right properties are set on the question
        assertEq(_vault.getUserFromProperties(questionIdOne, STAGE.CREATE_AND_VOTE, other3), other3);
        assertEq(_vault.getAmountFromProperties(questionIdOne, STAGE.CREATE_AND_VOTE, other3), 1e18);

        assertEq(_vault.getUserFromProperties(questionIdTwo, STAGE.CREATE_AND_VOTE, other3), other3);
        assertEq(_vault.getAmountFromProperties(questionIdTwo, STAGE.CREATE_AND_VOTE, other3), 1e18);

        // Verify that others arent updated
        assertEq(_vault.getUserFromProperties(questionIdOne, STAGE.CREATE_AND_VOTE, other), other);
        assertEq(_vault.getAmountFromProperties(questionIdOne, STAGE.CREATE_AND_VOTE, other), 1e18);

        assertEq(_vault.getUserFromProperties(questionIdTwo, STAGE.CREATE_AND_VOTE, other2), other2);
        assertEq(_vault.getAmountFromProperties(questionIdTwo, STAGE.CREATE_AND_VOTE, other2), 1e18);
        vm.stopPrank();

        // Publish the questions
        vm.prank(owner);
        _questionAPI.publishQuestion(questionIdOne, 25);
        vm.prank(owner);
        _questionAPI.publishQuestion(questionIdTwo, 25);

        // Verify that everyone can withdraw and accounting is done properly.
        vm.prank(other);
        _vault.withdrawMetric(questionIdOne, STAGE.CREATE_AND_VOTE);

        // Shouldn't have anything to withdraw here
        vm.prank(other);
        vm.expectRevert(Vault.NotTheDepositor.selector);
        _vault.withdrawMetric(questionIdTwo, STAGE.CREATE_AND_VOTE);

        // Check everything is updated correctly
        // Should decrease by 1e18
        assertEq(_vault.getMetricTotalLockedBalance(), 3e18);
        assertEq(_vault.getLockedMetricByQuestion(questionIdOne), 1e18);

        // Should remain the same
        assertEq(_vault.getLockedMetricByQuestion(questionIdTwo), 2e18);

        // Should be cleared
        assertEq(_vault.getUserFromProperties(questionIdOne, STAGE.CREATE_AND_VOTE, other), other);
        assertEq(_vault.getAmountFromProperties(questionIdOne, STAGE.CREATE_AND_VOTE, other), 0);

        // Other users also withdraw
        vm.prank(other2);
        _vault.withdrawMetric(questionIdTwo, STAGE.CREATE_AND_VOTE);

        vm.prank(other3);
        _vault.withdrawMetric(questionIdOne, STAGE.CREATE_AND_VOTE);

        vm.prank(other3);
        _vault.withdrawMetric(questionIdTwo, STAGE.CREATE_AND_VOTE);

        // Check everything is updated correctly
        // Should decrease by 3e18
        assertEq(_vault.getMetricTotalLockedBalance(), 0);
        assertEq(_vault.getLockedMetricByQuestion(questionIdOne), 0);

        // Should remain the same
        assertEq(_vault.getLockedMetricByQuestion(questionIdTwo), 0);

        // Should be cleared
        assertEq(_vault.getAmountFromProperties(questionIdOne, STAGE.CREATE_AND_VOTE, other), 0);
        assertEq(_vault.getAmountFromProperties(questionIdOne, STAGE.CREATE_AND_VOTE, other3), 0);

        assertEq(_vault.getAmountFromProperties(questionIdTwo, STAGE.CREATE_AND_VOTE, other2), 0);
        assertEq(_vault.getAmountFromProperties(questionIdTwo, STAGE.CREATE_AND_VOTE, other3), 0);

        assertEq(_metricToken.balanceOf(other), 100e18);
        assertEq(_metricToken.balanceOf(other2), 100e18);
        assertEq(_metricToken.balanceOf(other3), 100e18);
    }
}
