// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "@forge-std/Script.sol";
import "./RagPull.sol";

contract RagPullScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // address yourAddress = vm.addr(deployerPrivateKey);
        // vm.startBroadcast(deployerPrivateKey);

        // SimpleCoin coin = new SimpleCoin();

        // // Do whatever you want!

        // uint256 balance = coin.getBalance(yourAddress);
        // console.log("Your balance is: ", balance);

        // bool result = coin.sendCoin(yourAddress, 100);
        // console.log("Coin successfully sent: ", result);

        // balance = coin.getBalance(yourAddress);
        // console.log("Your new balance is: ", balance);
        
        // vm.stopBroadcast();
    }
}