// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract RagPull {
        mapping (address => uint) balances;

        event Transfer(address indexed _from, address indexed _to, uint256 _value);

        constructor() {
                balances[tx.origin] = 10000;
        }

}