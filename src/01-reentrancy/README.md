# 01 — Reentrancy

**Historical incident:** The DAO — June 17, 2016 — ~3.6M ETH drained (~$60M at the time), triggering the Ethereum / Ethereum Classic hard fork.

## The bug in one sentence

`withdraw()` sends ether via an external `call` **before** it zeroes the caller's balance, so a malicious contract can re-enter `withdraw()` from inside its `receive()` hook and drain the vault in a single transaction.

## Anatomy of the exploit

```
Attacker.attack()  →  EtherStore.withdraw()
                        ├── reads bal (1 ETH)
                        ├── calls Attacker.receive() with 1 ETH
                        │     └── Attacker.receive()  →  EtherStore.withdraw()
                        │                                 ├── reads bal (still 1 ETH!)
                        │                                 ├── calls Attacker.receive() with 1 ETH
                        │                                 │     └── ... loop until vault is empty
                        │                                 └── sets bal = 0  (way too late)
                        └── sets bal = 0
```

The vulnerable line is the **order** of the last three statements of `withdraw`. Nothing else.

## The two fixes (used together in `EtherStoreSafe`)

1. **Checks-Effects-Interactions** — always update state *before* making an external call. This alone kills the exploit.
2. **Reentrancy lock** — a mutex on top, so future edits to the function don't silently reintroduce the bug.

## Historical note

The DAO code was written in a Solidity version where `.call.value(x)()` was the idiomatic way to forward all remaining gas. Today's `msg.sender.call{value: x}("")` is functionally the same for this attack: 63/64ths of the remaining gas flows to the callee, which is more than enough to re-enter.

Later versions of Solidity did not fix reentrancy — the pattern is still exploitable in 0.8.24. What changed is the awareness in the community and the availability of `ReentrancyGuard` in OpenZeppelin.

## Running just this case

```bash
forge test --match-path test/01-reentrancy/*.t.sol -vvv
```

## Further reading

- [Phil Daian — Analysis of the DAO exploit](https://hackingdistributed.com/2016/06/18/analysis-of-the-dao-exploit/)
- [SWC-107 — Reentrancy](https://swcregistry.io/docs/SWC-107)
- [OpenZeppelin ReentrancyGuard source](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/ReentrancyGuard.sol)
