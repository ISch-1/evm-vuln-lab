# evm-vuln-lab

[![CI](https://github.com/ISch-1/evm-vuln-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/ISch-1/evm-vuln-lab/actions/workflows/ci.yml)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-blue)](https://docs.soliditylang.org/)
[![Foundry](https://img.shields.io/badge/tested_with-Foundry-orange)](https://book.getfoundry.sh/)

> A hands-on lab reproducing historical EVM vulnerabilities. Each case ships a **vulnerable contract**, a **fixed contract**, and an **executable Foundry exploit** that proves the attack works — and stops working after the fix.

The point isn't a blog post about reentrancy. The point is: `forge test` runs, watches ether drain out of the vulnerable contract, and watches the same attack fail against the patched version.

## Vulnerabilities covered

| # | Vulnerability | Real-world incident | Status |
|---|---------------|---------------------|--------|
| 01 | Reentrancy | [The DAO — June 2016, ~$60M](https://en.wikipedia.org/wiki/The_DAO_(organization)) | ✅ |
| 02 | Integer overflow / underflow | BEC token — April 2018 | 🚧 |
| 03 | Access control | [Parity multisig — July 2017, ~$30M](https://blog.openzeppelin.com/on-the-parity-wallet-multisig-hack-405a8c12e8f7) | 🚧 |
| 04 | `tx.origin` phishing | — | 🚧 |
| 05 | `delegatecall` / storage collision | [Parity multisig freeze — November 2017, ~$150M frozen](https://blog.openzeppelin.com/parity-wallet-hack-reloaded) | 🚧 |
| 06 | Oracle manipulation | bZx — February 2020 | 🚧 |

## Layout

```
evm-vuln-lab/
├── src/
│   └── 01-reentrancy/
│       ├── EtherStore.sol       # Vulnerable contract
│       ├── EtherStoreSafe.sol   # Patched with checks-effects-interactions + ReentrancyGuard
│       └── README.md            # The bug, the fix, the historical incident
├── test/
│   └── 01-reentrancy/
│       └── Reentrancy.t.sol     # Foundry test: exploit succeeds on vulnerable, fails on safe
├── foundry.toml
└── .github/workflows/ci.yml     # forge fmt --check + forge build + forge test (+ Slither)
```

## Running it

```bash
git clone https://github.com/ISch-1/evm-vuln-lab
cd evm-vuln-lab
forge install                       # installs forge-std
forge test -vv                      # runs everything
forge test --match-path test/01-reentrancy/*.t.sol -vvv   # one case, verbose traces
```

Output you should see for case 01:

```
[PASS] test_Exploit_DrainsEtherStore()  (gas: ...)
  attacker_balance_before: 0
  etherstore_balance_before: 5 ether
  attacker_balance_after:  5 ether     <-- drained
  etherstore_balance_after: 0

[PASS] test_Fix_ExploitFails()  (gas: ...)
  reverted with: ReentrancyGuardReentrantCall()
```

## Design notes (why the code looks like this)

- **One vulnerability per folder**, self-contained. No shared abstractions until at least three cases justify one.
- **The fix uses the same interface as the vulnerable version.** Makes the exploit test double as a regression test.
- **Historical accuracy over pedagogical simplicity** where it doesn't hurt readability. Where TheDAO used `send`/`call.value()` idioms of Solidity 0.4, the modern-day equivalent (`call{value: ...}`) is used, with a note in the case README.

## Roadmap

- [ ] Case 02 — integer overflow (Solidity < 0.8, BEC token)
- [ ] Case 03 — access control (Parity multisig)
- [ ] Case 04 — `tx.origin`
- [ ] Case 05 — `delegatecall` storage collision
- [ ] Slither in CI as a required check
- [ ] Case 06 — oracle manipulation (bZx)
- [ ] Gas report per case (`forge test --gas-report`)

## References

- [SWC Registry](https://swcregistry.io/) — Smart Contract Weakness Classification
- [Rekt Leaderboard](https://rekt.news/leaderboard/) — real-world losses, sorted
- [SigmaPrime — Solidity known attacks](https://consensys.github.io/smart-contract-best-practices/attacks/)

## License

MIT — see [LICENSE](LICENSE).
