// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../Helpers/QuickSetup.sol";

contract CreationTest is QuickSetup {
    function setUp() public {
        quickSetup();
    }

    // ---------------------- General tests ----------------------
    function test_AnyoneCanCreateAQuestion() public {
        console.log("Anyone should be able to create a question");
        vm.prank(other);
        _questionAPI.createQuestion("ipfs://A");
        assertEq(1, _bountyQuestion.getMostRecentQuestion());

        vm.prank(other2);
        _questionAPI.createQuestion("ipfs://B");
        assertEq(2, _bountyQuestion.getMostRecentQuestion());

        vm.prank(other3);
        _questionAPI.createQuestion("ipfs://C");
        assertEq(3, _bountyQuestion.getMostRecentQuestion());
    }
}
