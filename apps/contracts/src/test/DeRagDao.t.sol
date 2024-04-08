// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {DeRagDao} from "../DeRagDao.sol";
import {DeRagDaoToken} from "../DeRagDaoToken.sol";
contract DeRagDaoTest is Test {
    DeRagDao public deRagDao;
    DeRagDaoToken token;
    // lighthouse testnet contract
    function setUp() public {

        // foundry default sender
        address validator = address(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496);
        // address validator = address(0xE55Bf74671eD2a79bCC8843dfB763d6581B45826);
        // https://calibration.filfox.info/en/address/0x4015c3E5453d38Df71539C0F7440603C69784d7a?t=3
        // https://github.com/lighthouse-web3/raas-starter-kit/tree/main?tab=readme-ov-file#using-lighthouse-raas-services
        address lighthouse = address(0x4015c3E5453d38Df71539C0F7440603C69784d7a);
        

        // for simplicity, we mint with tester=validator
        token = new DeRagDaoToken("DeRagDaoToken", "DRT");

        deRagDao = new DeRagDao(validator,lighthouse, address(token));
        // fund all back to DAO treasury
        token.transfer(address(deRagDao), 1000000000000000000000000);

        console.log('balance validator', token.balanceOf(validator));
        console.log('balance validator', token.balanceOf(address(deRagDao)));
    }
    
    // bytes version we got from explorer cannot be used
    // bytes memory cid = "0x516d4e766a78617170526958376f3255354d514138445a637a3754316463746a616e335a50483273463548793969";
    function test_VerifyWithDeal() public {

        address indexer = address(0x4513e09002228b6F9bfac47CFaA0c58D5227a0a3);
    
        bytes memory cid = "QmNvjxaqpRiX7o2U5MQA8DZcz7T1dctjan3ZPH2sF5Hy9i";
        deRagDao.verify(indexer, cid);

        assertEq(token.balanceOf(indexer),1000); 

    }
    function test_VerifyNoDeal() public {
        vm.expectRevert(bytes("Deals must be at least 1"));
        address indexer = address(0x4513e09002228b6F9bfac47CFaA0c58D5227a0a3);
        // non exist cid
        bytes memory cid = "QmNvjxaqpRiX7o2U5MQA8DZcz7T1dctjanZPH2sF5Hy0i";
        deRagDao.verify(indexer, cid);

        assertEq(token.balanceOf(address(deRagDao)),1000000000000000000000000); 
        assertEq(token.balanceOf(indexer),0); 
    }



  
}
