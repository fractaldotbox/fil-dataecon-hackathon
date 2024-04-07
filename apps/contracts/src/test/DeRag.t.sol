// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {DeRag} from "../DeRag.sol";

contract DeRagTest is Test {
    DeRag public deRag;

    // lighthouse testnet contract
    function setUp() public {

        // foundry default sender
        address validator = address(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496);
        // address validator = address(0xE55Bf74671eD2a79bCC8843dfB763d6581B45826);
        // https://calibration.filfox.info/en/address/0x4015c3E5453d38Df71539C0F7440603C69784d7a?t=3
        // https://github.com/lighthouse-web3/raas-starter-kit/tree/main?tab=readme-ov-file#using-lighthouse-raas-services
        address lighthouse = address(0x4015c3E5453d38Df71539C0F7440603C69784d7a);
        
        deRag = new DeRag(validator,lighthouse);
    }
    

    function test_Verify() public {
        vm.expectRevert(bytes("Deals must be at least 1"));
        address indexer = address(0x4513e09002228b6F9bfac47CFaA0c58D5227a0a3);
        bytes memory cid = "0x516d4e766a78617170526958376f3255354d514138445a637a3754316463746a616e335a50483273463548793969";
        deRag.verify(indexer, cid);

    }

  
}
