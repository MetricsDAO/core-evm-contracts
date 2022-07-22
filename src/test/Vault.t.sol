pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../contracts/Protocol/Vault.sol";
import "../contracts/MetricToken.sol";
import "@contracts/Protocol/QuestionAPI.sol";
import "@contracts/Protocol/ActionCostController.sol";
import "@contracts/Protocol/ClaimController.sol";

contract vaultTest is Test {
    // Accounts
    address owner = address(0x0a);
    address Alice = address(0x0b);
    address Bob = address(0x0c);

    MetricToken _metricToken;
    Vault _vault;
    QuestionAPI _questionAPI;
    ClaimController _claimController;
    BountyQuestion _bountyQuestion;
    ActionCostController _costController;
    QuestionStateController _questionStateController;

    // NFT _mockAuthNFT;

    function setUp() public {
        // Label addresses
        vm.label(owner, "Owner");
        vm.label(Alice, "Alice");
        vm.label(Bob, "Bob");

        vm.startPrank(owner);
        // _mockAuthNFT = new NFT("Auth", "Auth");
        _metricToken = new MetricToken();
        _bountyQuestion = new BountyQuestion();
        _questionStateController = new QuestionStateController();
        _costController = new ActionCostController(address(_metricToken), address(_vault));
        _questionAPI = new QuestionAPI(
            address(_bountyQuestion),
            address(_questionStateController),
            address(_claimController),
            address(_costController)
        );
        _costController.setQuestionApi(address(_questionAPI));
        _questionStateController.setQuestionApi(address(_questionAPI));
        _bountyQuestion.setQuestionApi(address(_questionAPI));

        _metricToken.transfer(owner, 100e18);

        // _mockAuthNFT.mintTo(manager);

        vm.stopPrank();
    }

    // ---------------------- General functionality testing

    function test_lockMetric() public {
        console.log("Should lock Metric.");

        vm.startPrank(owner);
        // Create a question and see that it is created and balance is updated.
        _metricToken.approve(address(_costController), 100e18);
        uint256 questionIdOne = _questionAPI.createQuestion("ipfs://XYZ", 25);
        assertEq(_metricToken.balanceOf(owner), 99e18);

        // Assert that the question is now a VOTING and has the correct data (claim limit).
        assertEq(_questionStateController.getState(questionIdOne), uint256(IQuestionStateController.STATE.VOTING));
        assertEq(_claimController.getClaimLimit(questionIdOne), 25);

        vm.stopPrank();
    }
}
