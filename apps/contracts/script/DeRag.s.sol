// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

contract DeRagScript is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_WALLET_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        // console.log('deployer address', deployerAddress);
    }
}
