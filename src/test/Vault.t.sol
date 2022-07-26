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
        console.log("Should have double the locked Metric with second deposit.");

        vm.startPrank(other);
        // Create 1st question
        _metricToken.approve(address(_vault), 100e18);
        _questionAPI.createQuestion("ipfs://XYZ", 25);

        // Create 2nd question
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

        // Publish question
        _questionAPI.publishQuestion(questionId);

        //withdraw Metric
        _vault.withdrawMetric(questionId);
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

        //slash Metric
        vm.startPrank(owner);
        _vault.slashMetric(questionId);
        vm.stopPrank();

        // Check that Metric is slashed
        assertEq(_metricToken.balanceOf(other), 99.5e18);
        // Check treasury Metric balance
        assertEq(_metricToken.balanceOf(treasury), 0.5e18);
    }

    // ---------------------- Access control testing
    function test_onlyOwnerCanSlashMetric() public {
        console.log("Only owner should be able to slash a question");

        vm.startPrank(other);
        // Create question
        _metricToken.approve(address(_vault), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);

        //slash Metric
        vm.expectRevert("Ownable: caller is not the owner");
        _vault.slashMetric(questionId);
        vm.stopPrank();
    }

    function test_cannotSlashSameQuestionTwice() public {
        console.log("We can only slash a question once.");

        vm.startPrank(other);
        // Create question
        _metricToken.approve(address(_vault), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);
        vm.stopPrank();

        vm.startPrank(owner);
        // Slash
        _vault.slashMetric(questionId);

        // Slash again
        vm.expectRevert(Vault.AlreadySlashed.selector);
        _vault.slashMetric(questionId);
        vm.stopPrank();
    }

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
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);

        //withdraw Metric
        vm.expectRevert(Vault.QuestionNotPublished.selector);
        _vault.withdrawMetric(questionId);
        vm.stopPrank();
    }

    function test_cannotWithdrawSameQuestionTwice() public {
        console.log("Should not withdraw Metric twice");
        vm.startPrank(other);

        // Create question
        _metricToken.approve(address(_vault), 100e18);
        uint256 questionId = _questionAPI.createQuestion("ipfs://XYZ", 25);

        // Publish question
        _questionAPI.publishQuestion(questionId);

        // Withdraw Metric
        _vault.withdrawMetric(questionId);

        // Withdraw again
        vm.expectRevert(Vault.NoMetricToWithdraw.selector);
        _vault.withdrawMetric(questionId);

        vm.stopPrank();
    }
}
