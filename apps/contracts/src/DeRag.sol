// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract DeRag is AccessControl {
  // Create a new role identifier for the validator role
  bytes32 public constant VALIDATOR_ROLE = keccak256('VALIDATOR_ROLE');

  ILighthouseDealStatus public dealStatus;

  error CallerNotValidator(address caller);

  mapping(address => uint) balances;

  event Transfer(address indexed _from, address indexed _to, uint256 _value);

  constructor(address validatork, address lighthouseDealStatus) {
    _grantRole(VALIDATOR_ROLE, validator);
    balances[tx.origin] = 10000;

    dealStatus = ILighthouseDealStatus(lighthouseDealStatus);
  }

  function verify(address _to, string cid) public returns (bool success) {
    if (!hasRole(VALIDATOR_ROLE, msg.sender)) {
      revert CallerNotValidator(msg.sender);
    }

    deals = dealStatus.getActiveDeals(cid);

    require(deals.length >= 1, 'Active deals must be at least 1');

    balances[_to] += 1;
  }
}
