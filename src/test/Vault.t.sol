pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../contracts/Protocol/Vault.sol";
import "../contracts/MetricToken.sol";

/// @notice Translation of https://github.com/MetricsDAO/core-evm-contracts/blob/main/test/chef-test.js to foundry
contract vaultTest is Test {
    // Accounts
    address owner = address(0x152314518);
    address Alice = address(0xa);
    address Bob = address(0xb);

    MetricToken metricToken;
    Vault vault;

    function setUp() public {
        // Label addresses
        vm.label(owner, "Owner");
        vm.label(Alice, "Alice");
        vm.label(Bob, "Bob");

        // Deploy METRIC & Vault
        vm.startPrank(owner);
        metricToken = new MetricToken();
        vault = new Vault(address(metricToken));

        vm.label(address(metricToken), "METRIC");
        vm.label(address(vault), "vault");

        vm.stopPrank();
    }

    function test_lockMetric() public {
        console.log("Test locking Metric.");
    }
}
