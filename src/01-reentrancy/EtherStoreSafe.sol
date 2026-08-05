// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title EtherStoreSafe
/// @notice Same interface as `EtherStore`, patched with two independent defences:
///         1. Checks-Effects-Interactions ordering (state updated before call).
///         2. A reentrancy lock as belt-and-suspenders for future refactors.
contract EtherStoreSafe {
    error ReentrancyGuardReentrantCall();
    error NoBalance();
    error SendFailed();

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    mapping(address => uint256) public balances;

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrancyGuardReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external nonReentrant {
        uint256 bal = balances[msg.sender];
        if (bal == 0) revert NoBalance();

        // ✅ effect BEFORE interaction
        balances[msg.sender] = 0;

        (bool ok,) = msg.sender.call{value: bal}("");
        if (!ok) revert SendFailed();
    }

    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
