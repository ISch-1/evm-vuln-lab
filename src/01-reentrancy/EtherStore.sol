// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title EtherStore (vulnerable)
/// @notice Reproduces the reentrancy pattern behind The DAO exploit (June 2016).
/// @dev The bug lives in `withdraw`: state is updated *after* the external call.
///      An attacker whose `receive()` re-enters `withdraw` reads a still-non-zero
///      balance and drains the contract in one transaction.
contract EtherStore {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 bal = balances[msg.sender];
        require(bal > 0, "no balance");

        // ❌ external call happens BEFORE state update
        (bool ok,) = msg.sender.call{value: bal}("");
        require(ok, "send failed");

        // by the time we reach this line, `msg.sender.receive()` may have
        // already re-entered withdraw() any number of times.
        balances[msg.sender] = 0;
    }

    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
