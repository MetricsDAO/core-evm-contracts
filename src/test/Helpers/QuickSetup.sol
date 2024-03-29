// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "@contracts/MetricToken.sol";
import "@contracts/Xmetric.sol";
import "@contracts/Protocol/QuestionAPI.sol";
import "@contracts/Protocol/ClaimController.sol";
import "@contracts/Protocol/QuestionStateController.sol";
import "@contracts/Protocol/BountyQuestion.sol";
import "@contracts/Protocol/ActionCostController.sol";
import "@contracts/Protocol/Vault.sol";
import "@contracts/Protocol/Extra/PseudoAuthNFT.sol";

import "../../contracts/Protocol/Enums/ActionEnum.sol";
import "../../contracts/Protocol/Enums/VaultEnum.sol";
import "../../contracts/Protocol/Enums/QuestionStateEnum.sol";
import "../../contracts/Protocol/Enums/ClaimEnum.sol";

abstract contract QuickSetup is Test {
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
    Xmetric _xmetric;
    QuestionAPI _questionAPI;
    BountyQuestion _bountyQuestion;
    ClaimController _claimController;
    ActionCostController _costController;
    QuestionStateController _questionStateController;
    Vault _vault;
    PseudoAuthNFT _mockAuthNFTManager;
    PseudoAuthNFT _mockAuthNFTAdmin;

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

    function quickSetup() public {
        // Labeling
        vm.label(owner, "Owner");
        vm.label(other, "User");
        vm.label(manager, "Manager");

        vm.startPrank(owner);
        // Deploy all contracts
        _mockAuthNFTManager = new PseudoAuthNFT("Auth", "Auth");
        _mockAuthNFTAdmin = new PseudoAuthNFT("Auth", "Auth");
        _metricToken = new MetricToken();
        _bountyQuestion = new BountyQuestion();
        _claimController = new ClaimController();
        _questionStateController = new QuestionStateController();
        _vault = new Vault(treasury);
        _costController = new ActionCostController(address(_vault));
        _questionAPI = new QuestionAPI(
            address(_bountyQuestion),
            address(_questionStateController),
            address(_claimController),
            address(_costController),
            address(_metricToken),
            address(_vault)
        );

        // Make required calls
        _claimController.setQuestionApi(address(_questionAPI));
        _claimController.setQuestionApiMT(address(_questionAPI));
        _costController.setQuestionApi(address(_questionAPI));
        _questionStateController.setQuestionApi(address(_questionAPI));
        _bountyQuestion.setQuestionApi(address(_questionAPI));
        _bountyQuestion.setQuestionApiSC(address(_questionAPI));
        _vault.setQuestionApi(address(_questionAPI));
        _vault.setQuestionApiCC(address(_questionAPI));

        _claimController.updateMetric();

        _bountyQuestion.updateStateController();

        _questionStateController.updateBountyQuestion();

        _vault.updateStateController();
        _vault.updateClaimController();
        _vault.updateCostController();
        _vault.updateBountyQuestion();
        _vault.updateMetric();

        _costController.setActionCost(ACTION.CREATE, 1e18);
        _costController.setActionCost(ACTION.VOTE, 1e18);
        _costController.setActionCost(ACTION.CLAIM, 1e18);
        _costController.setActionCost(ACTION.CHALLENGE_BURN, 1000e18);

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

    function quickSetupXmetric() public {
        // Labeling
        vm.label(owner, "Owner");
        vm.label(other, "User");
        vm.label(manager, "Manager");

        vm.startPrank(owner);
        // Deploy all contracts
        _mockAuthNFTManager = new PseudoAuthNFT("Auth", "Auth");
        _mockAuthNFTAdmin = new PseudoAuthNFT("Auth", "Auth");
        _xmetric = new Xmetric();
        _bountyQuestion = new BountyQuestion();
        _claimController = new ClaimController();
        _questionStateController = new QuestionStateController();
        _vault = new Vault(treasury);
        _costController = new ActionCostController(address(_vault));
        _questionAPI = new QuestionAPI(
            address(_bountyQuestion),
            address(_questionStateController),
            address(_claimController),
            address(_costController),
            address(_xmetric),
            address(_vault)
        );

        // Make required calls
        _claimController.setQuestionApi(address(_questionAPI));
        _claimController.setQuestionApiMT(address(_questionAPI));
        _costController.setQuestionApi(address(_questionAPI));
        _questionStateController.setQuestionApi(address(_questionAPI));
        _bountyQuestion.setQuestionApi(address(_questionAPI));
        _bountyQuestion.setQuestionApiSC(address(_questionAPI));
        _vault.setQuestionApi(address(_questionAPI));
        _vault.setQuestionApiCC(address(_questionAPI));

        _bountyQuestion.updateStateController();

        _questionStateController.updateBountyQuestion();

        _vault.updateStateController();
        _vault.updateClaimController();
        _vault.updateCostController();
        _vault.updateBountyQuestion();
        _vault.updateMetric();

        _costController.setActionCost(ACTION.CREATE, 1e18);
        _costController.setActionCost(ACTION.VOTE, 1e18);
        _costController.setActionCost(ACTION.CLAIM, 1e18);
        _costController.setActionCost(ACTION.CHALLENGE_BURN, 1000e18);

        _xmetric.transfer(other, 100e18);
        _xmetric.transfer(other2, 100e18);
        _xmetric.transfer(other3, 100e18);

        _questionAPI.addHolderRole(PROGRAM_MANAGER_ROLE, address(_mockAuthNFTManager));
        _questionAPI.addHolderRole(ADMIN_ROLE, address(_mockAuthNFTAdmin));

        _mockAuthNFTManager.mintTo(manager);
        _mockAuthNFTAdmin.mintTo(other);

        _xmetric.setTransactor(address(_vault), true);

        vm.stopPrank();

        vm.prank(owner);
        _xmetric.approve(address(_vault), 100e18);

        vm.prank(manager);
        _xmetric.approve(address(_vault), 100e18);

        vm.prank(other);
        _xmetric.approve(address(_vault), 100e18);

        vm.prank(other2);
        _xmetric.approve(address(_vault), 100e18);

        vm.prank(other3);
        _xmetric.approve(address(_vault), 100e18);
    }
}
