// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ILighthouseDealStatus} from "./interfaces/ILighthouseDealStatus.sol";
import {DeRagDaoToken} from "./DeRagDaoToken.sol";

contract DeRagDao is AccessControl {
  // Create a new role identifier for the validator role
  bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

  ILighthouseDealStatus public dealStatus;

  DeRagDaoToken token;

  error CallerNotValidator(address caller);

  event Transfer(address indexed _from, address indexed _to, uint256 _value);

  constructor(address validator, address lighthouse, address daoToken) {
    _grantRole(VALIDATOR_ROLE, validator);

    // control erc20
    token = DeRagDaoToken(daoToken);

    dealStatus = ILighthouseDealStatus(lighthouse);
  }

  function verify(address _to, bytes memory cid) public returns (bool success) {
    if (!hasRole(VALIDATOR_ROLE, msg.sender)) {
      revert CallerNotValidator(msg.sender);
    }

    ILighthouseDealStatus.Deal[] memory deals = dealStatus.getAllDeals(cid);

    require(deals.length >= 1, "Deals must be at least 1");

    token.transfer(_to, 1000);

    emit Transfer(address(this), _to, 1000);

    return true;
  }
}
