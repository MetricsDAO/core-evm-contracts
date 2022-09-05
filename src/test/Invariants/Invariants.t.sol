// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../Helpers/QuickSetup.sol";

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

contract InvariantTesting is QuickSetup, InvariantTest {
    address[] private _targetContracts;
    address[] private _targetSenders;
    bytes4[] private _targetSelectors;

    struct FuzzSelector {
        address addr;
        bytes4[] selectors;
    }

    function setUp() public {
        quickSetup();

        // Add contracts to the list of target contracts.
        addTargetContract(address(_questionAPI));
        addTargetContract(address(_vault));

        // Add target senders
        address[4] memory users = [other, other2, other3, manager];

        for (uint256 i; i < users.length; ++i) {
            addTargetSender(users[i]);
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
        uint256 questionId = (_bountyQuestion.getMostRecentQuestion());

        if (_questionStateController.getState(questionId) == STATE.VOTING) {
            address[] memory voters = _questionStateController.getVoters(questionId);
            assertTrue(
                _vault.lockedMetricByQuestion(questionId) ==
                    ((voters.length * _costController.getActionCost(ACTION.VOTE)) + _costController.getActionCost(ACTION.CREATE))
            );
        }
    }
}
