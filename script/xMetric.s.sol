pragma solidity 0.8.13;

import "forge-std/Script.sol";
import {Xmetric} from "../src/contracts/Xmetric.sol";

contract XmetricScript is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();
        new Xmetric();
    }
}
