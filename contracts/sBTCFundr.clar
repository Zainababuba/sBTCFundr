;; sBTCFundr

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MIN_CONTRIBUTION u1000000) ;; Minimum contribution in microSTX
(define-constant VOTING_PERIOD u144) ;; ~24 hours in blocks
(define-constant PROPOSAL_THRESHOLD u100000000) ;; Minimum pool size for proposals

;; Error codes
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_FUNDS (err u101))
(define-constant ERR_POOL_NOT_FOUND (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_ALREADY_VOTED (err u104))
(define-constant ERR_VOTING_CLOSED (err u105))
(define-constant ERR_BELOW_THRESHOLD (err u106))
(define-constant ERR_INVALID_METADATA (err u107))
(define-constant ERR_STAKE_NOT_FOUND (err u108))
(define-constant ERR_ALREADY_STAKED (err u109))
(define-constant ERR_MERGER_FAILED (err u110))
(define-constant ERR_SAME_POOL (err u111))
(define-constant ERR_UNSTAKING_LOCKED (err u112))

;; Data Maps
(define-map pools
    { pool-id: uint }
    {
        total-funds: uint,
        active: bool,
        creator: principal,
        created-at: uint
    }
)

(define-map contributions
    { pool-id: uint, contributor: principal }
    { amount: uint }
)

(define-map proposals
    { pool-id: uint, proposal-id: uint }
    {
        startup: principal,
        amount: uint,
        description: (string-utf8 256),
        votes-for: uint,
        votes-against: uint,
        status: (string-utf8 20),
        created-at: uint
    }
)

(define-map votes
    { pool-id: uint, proposal-id: uint, voter: principal }
    { vote: bool }
)

;; Pool counter
(define-data-var pool-counter uint u0)
(define-data-var proposal-counter uint u0)
(define-data-var reward-rate uint u5000) ;; 0.005 STX per block per contribution unit

;; FEATURE 1: Pool Metadata
(define-map pool-metadata
    { pool-id: uint }
    {
        name: (string-utf8 64),
        description: (string-utf8 256),
        category: (string-utf8 64),
        logo-uri: (string-utf8 256)
    }
)

;; FEATURE 2: Staking & Rewards
(define-map staking-info
    { pool-id: uint, staker: principal }
    {
        staked-amount: uint,
        staked-at: uint,
        last-reward-claim: uint
    }
)

;; FEATURE 3: Pool Merging
(define-map merger-proposals
    { source-pool-id: uint, target-pool-id: uint }
    {
        proposed-by: principal,
        votes-for: uint,
        votes-against: uint,
        created-at: uint,
        status: (string-utf8 20)
    }
)
