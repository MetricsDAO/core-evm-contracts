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
import {MockAuthNFT} from "@contracts/Protocol/Extra/MockAuthNFT.sol";

import "@contracts/Protocol/Enums/ActionEnum.sol";
import "@contracts/Protocol/Enums/VaultEnum.sol";
import "@contracts/Protocol/Enums/QuestionStateEnum.sol";
import "@contracts/Protocol/Enums/ClaimEnum.sol";

contract QuestionApiScript is Script {
    bytes32 public constant PROGRAM_MANAGER_ROLE = keccak256("PROGRAM_MANAGER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    MetricToken _metricToken;
    QuestionAPI _questionAPI;
    BountyQuestion _bountyQuestion;
    ClaimController _claimController;
    ActionCostController _costController;
    QuestionStateController _questionStateController;
    Vault _vault;
    MockAuthNFT _mockAuthNFTManager;
    MockAuthNFT _mockAuthNFTAdmin;

    function run() public {
        vm.startBroadcast();
        _mockAuthNFTManager = new MockAuthNFT("Auth", "Auth");
        _mockAuthNFTAdmin = new MockAuthNFT("Auth", "Auth");
        _metricToken = new MetricToken();
        _bountyQuestion = new BountyQuestion();
        _claimController = new ClaimController();
        _questionStateController = new QuestionStateController(address(_bountyQuestion));
        _vault = new Vault(address(_metricToken), address(_questionStateController), address(0));
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
        _bountyQuestion.setStateController(address(_questionStateController));

        _questionAPI.addHolderRole(PROGRAM_MANAGER_ROLE, address(_mockAuthNFTManager));
        _questionAPI.addHolderRole(ADMIN_ROLE, address(_mockAuthNFTAdmin));

        _mockAuthNFTManager.mintTo(msg.sender);
        _mockAuthNFTAdmin.mintTo(msg.sender);

        _metricToken.approve(address(_vault), 1000e18);

        vm.stopBroadcast();
    }
}
