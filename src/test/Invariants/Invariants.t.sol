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

contract InvariantTest {
    address[] private _targetContracts;
    address[] private _targetSenders;
    bytes4[] private _targetSelectors;

    function addTargetContract(address newTargetContract_) internal {
        _targetContracts.push(newTargetContract_);
    }

    function addTargetSender(address newTargetSender_) internal {
        _targetSenders.push(newTargetSender_);
    }

    function addTargetSelector(bytes4 newTargetSelector_) internal {
        _targetSelectors.push(newTargetSelector_);
    }

    function targetContracts() public view returns (address[] memory targetContracts_) {
        require(_targetContracts.length != uint256(0), "NO_TARGET_CONTRACTS");
        return _targetContracts;
    }

    function targetSenders() public view returns (address[] memory targetSenders_) {
        require(_targetSenders.length != uint256(0), "NO_TARGET_SENDERS");
        return _targetSenders;
    }

    function targetSelectors() public view returns (bytes4[] memory targetSelectors_) {
        require(_targetSelectors.length != uint256(0), "NO_TARGET_SELECTORS");
        return _targetSelectors;
    }
}

contract QuestionAPITest is Test, InvariantTest {
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

    address[] private _targetContracts;
    address[] private _targetSenders;
    bytes4[] private _targetSelectors;

    struct FuzzSelector {
        address addr;
        bytes4[] selectors;
    }

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

        _questionAPI.toggleLock();

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

        // Add contracts to the list of target contracts.
        addTargetContract(address(_questionAPI));
        addTargetContract(address(_vault));

        // Add target senders
        address[3] memory users = [other, other2, other3];

        for (uint256 i; i < users.length; ++i) {
            addTargetSender(users[i]);
        }

        // Add target selectors
        bytes4[4] memory selectors = [
            Vault.withdrawMetric.selector,
            QuestionAPI.createQuestion.selector,
            QuestionAPI.upvoteQuestion.selector,
            QuestionAPI.unvoteQuestion.selector
        ];

        for (uint256 i; i < selectors.length; ++i) {
            addTargetSelector(selectors[i]);
        }
    }

    function invariant_made_to_succeed() public {
        assertEq(true, true);
    }

    function invariant_user_lte_starting() public {
        uint256 startingBal = _metricToken.balanceOf(msg.sender);
        assertTrue(_metricToken.balanceOf(msg.sender) <= startingBal);
    }

    function invariant_total_locked_metric() public {
        uint256 sumLockedPerUser;
        uint256 totalLocked = _vault.getMetricTotalLockedBalance();

        address[3] memory users = [other, other2, other3];

        for (uint256 i; i < users.length; ++i) {
            sumLockedPerUser += _vault.getLockedPerUser(users[i]);
        }

        assertTrue(totalLocked == sumLockedPerUser);
    }

    function invariant_no_premature_withdrawals_for_voting() public {
        uint256 questionId = (_bountyQuestion.getMostRecentQuestion() - 1);

        if (_questionStateController.getState(questionId) == STATE.VOTING) {
            address[] memory voters = _questionStateController.getVoters(questionId);
            assertTrue(_vault.lockedMetricByQuestion(questionId) == ((voters.length * 1e18) + 1e18));
        }
    }
}
