// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ILighthouseDealStatus} from "./interfaces/ILighthouseDealStatus.sol";

contract DeRag is AccessControl {
  // Create a new role identifier for the validator role
  bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

  ILighthouseDealStatus public dealStatus;

  error CallerNotValidator(address caller);

  mapping(address => uint) balances;

  event Transfer(address indexed _from, address indexed _to, uint256 _value);

  constructor(address validator, address lighthouseAddress) {
    _grantRole(VALIDATOR_ROLE, validator);
    balances[tx.origin] = 10000;

    // control erc20

    dealStatus = ILighthouseDealStatus(lighthouseAddress);
  }

  function verify(address _to, bytes memory cid) public returns (bool success) {
    if (!hasRole(VALIDATOR_ROLE, msg.sender)) {
      revert CallerNotValidator(msg.sender);
    }

    // bytes[] memory cids = dealStatus.getAllCIDs();

    ILighthouseDealStatus.Deal[] memory deals = dealStatus.getAllDeals(cid);

    require(deals.length >= 1, "Deals must be at least 1");

    balances[_to] += 1;

    emit Transfer(address(0), _to, 1);

    return true;
  }
}
