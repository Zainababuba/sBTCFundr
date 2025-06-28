# sBTCFundr - Decentralized Funding Pools – Clarity Smart Contract

This Clarity smart contract facilitates decentralized funding, proposal voting, and staking mechanisms on the Stacks blockchain. It enables community-driven startup funding through pools, with advanced features such as pool metadata, staking rewards, and pool mergers.

---

## 📌 Features Overview

| Feature                       | Description                                             |
| ----------------------------- | ------------------------------------------------------- |
| 🏗 Create Funding Pools       | Users can create and contribute to STX funding pools.   |
| 🗳 Submit & Vote on Proposals | Contributors can propose and vote on fund allocations.  |
| 🎨 Pool Metadata              | Add descriptive metadata like name, logo, and category. |
| 💎 Staking & Rewards          | Stake contributions and earn rewards per block.         |
| 🔄 Pool Merging               | Merge two funding pools through community votes.        |

---

## 🛠 Constants

```clojure
CONTRACT_OWNER: tx-sender
MIN_CONTRIBUTION: u1000000 (1 STX)
VOTING_PERIOD: u144 (~24 hours in blocks)
PROPOSAL_THRESHOLD: u100000000 (100 STX)
REWARD_RATE: u5000 (0.005 STX per block per unit)
```

---

## 🔐 Error Codes

| Code | Meaning                                  |
| ---- | ---------------------------------------- |
| 100  | Not authorized                           |
| 101  | Insufficient funds                       |
| 102  | Pool not found                           |
| 103  | Invalid amount                           |
| 104  | Already voted                            |
| 105  | Voting closed                            |
| 106  | Below proposal threshold                 |
| 107  | Invalid metadata                         |
| 108  | Stake not found                          |
| 109  | Already staked                           |
| 110  | Merger failed                            |
| 111  | Cannot merge the same pool               |
| 112  | Unstaking locked due to active proposals |

---

## 📂 Data Structures

### Maps

* `pools`: Stores pool data including creator, status, and total funds.
* `contributions`: Tracks individual user contributions per pool.
* `proposals`: Startup funding proposals submitted to a pool.
* `votes`: Vote records per user per proposal.
* `pool-metadata`: Stores metadata like name, description, category, and logo URI.
* `staking-info`: Keeps staking details including amounts and timestamps.
* `merger-proposals`: Tracks active merger proposals between pools.

### Data Variables

* `pool-counter`, `proposal-counter`: Counters for unique pool/proposal IDs.
* `reward-rate`: Adjustable staking reward per block.

---

## 🧑‍💻 Public Functions

### 🎯 Pool Management

* `create-pool`: Creates a new funding pool.
* `contribute (pool-id, amount)`: Contribute STX to an existing pool.
* `set-pool-metadata (pool-id, name, description, category, logo-uri)`: Set descriptive metadata.
* `get-pool`, `get-contribution`: Read-only access to pool and contribution info.

### 💡 Proposal System

* `submit-proposal (pool-id, startup, amount, description)`: Submit a funding proposal.
* `vote (pool-id, proposal-id, vote-for)`: Vote for or against a proposal.
* `execute-proposal (pool-id, proposal-id)`: Execute if voting passed after VOTING\_PERIOD.

### 🏷 Pool Metadata

* `get-pool-metadata (pool-id)`: Retrieve pool metadata.
* `get-pools-by-category (category, limit)`: Placeholder for off-chain indexing.

---

### 💸 Staking & Rewards

* `stake-contribution (pool-id, amount)`: Stake part of your contribution.
* `claim-staking-rewards (pool-id)`: Claim accrued staking rewards.
* `unstake-contribution (pool-id, amount)`: Withdraw staked amount (no active proposals allowed).
* `set-reward-rate (new-rate)`: Contract owner can adjust reward rate.
* `get-staking-info`, `get-pending-rewards`: Read-only functions.

---

### 🔁 Pool Merging

* `propose-pool-merger (source-pool-id, target-pool-id)`: Propose to merge two pools.
* `vote-on-merger (source-pool-id, target-pool-id, vote-for)`: Vote on merger proposal.
* `execute-pool-merger (source-pool-id, target-pool-id)`: Finalize pool merger if passed.

---

## ⚙️ Execution Flow Summary

1. **Create a pool** → `create-pool`
2. **Fund the pool** → `contribute`
3. **Add metadata** → `set-pool-metadata`
4. **Submit proposal** → `submit-proposal`
5. **Vote** → `vote`
6. **Execute** → `execute-proposal`
7. **Stake to earn** → `stake-contribution`
8. **Claim rewards** → `claim-staking-rewards`
9. **Propose merger** → `propose-pool-merger`
10. **Merge pools** → `execute-pool-merger`

---

## 📈 Reward Calculation

```clojure
reward = staked-amount * reward-rate * (current-block - last-claim-block)
```

Rewards are only claimable if greater than 0.

---

## 🚫 Limitations / Future Work

* `get-pools-by-category` is a placeholder and would require **off-chain indexing**.
* No **contribution withdrawal** feature is implemented.
* `get-active-proposals-count` is stubbed (`u0`) and needs implementation to restrict unstaking.

---

## ✅ Security Notes

* Only the pool creator can modify metadata.
* Only contributors can vote or propose.
* Funds are only transferred after a successful vote and execution.
* Contract owner (deployer) has control over reward-rate configuration.

---

## 📚 Development

This contract uses [Clarity](https://docs.stacks.co/docs/write-smart-contracts/clarity-overview/), the smart contract language on Stacks.

### Deploy

1. Install [Clarinet](https://docs.stacks.co/docs/clarity/clarinet/overview/)
2. Add contract to `contracts/` directory.
3. Run:

```bash
clarinet check
clarinet test
clarinet deploy
```

---
