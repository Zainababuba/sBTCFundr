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


;; Read-only functions
(define-read-only (get-pool (pool-id uint))
    (map-get? pools { pool-id: pool-id })
)

(define-read-only (get-contribution (pool-id uint) (contributor principal))
    (map-get? contributions { pool-id: pool-id, contributor: contributor })
)

(define-read-only (get-proposal (pool-id uint) (proposal-id uint))
    (map-get? proposals { pool-id: pool-id, proposal-id: proposal-id })
)

(define-read-only (get-vote (pool-id uint) (proposal-id uint) (voter principal))
    (map-get? votes { pool-id: pool-id, proposal-id: proposal-id, voter: voter })
)

;; Create new pool
(define-public (create-pool)
    (let
        ((new-pool-id (+ (var-get pool-counter) u1)))
        (map-set pools
            { pool-id: new-pool-id }
            {
                total-funds: u0,
                active: true,
                creator: tx-sender,
                created-at: stacks-block-height
            }
        )
        (var-set pool-counter new-pool-id)
        (ok new-pool-id)
    )
)

;; Contribute to pool
(define-public (contribute (pool-id uint) (amount uint))
    (let
        ((pool (unwrap! (get-pool pool-id) ERR_POOL_NOT_FOUND))
         (current-contribution (default-to { amount: u0 }
            (get-contribution pool-id tx-sender))))

        ;; Checks
        (asserts! (>= amount MIN_CONTRIBUTION) ERR_INVALID_AMOUNT)
        (asserts! (get active pool) ERR_POOL_NOT_FOUND)

        ;; Transfer STX to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

        ;; Update pool and contribution records
        (map-set pools
            { pool-id: pool-id }
            (merge pool { total-funds: (+ (get total-funds pool) amount) })
        )
        (map-set contributions
            { pool-id: pool-id, contributor: tx-sender }
            { amount: (+ amount (get amount current-contribution)) }
        )
        (ok true)
    )
)

;; Submit proposal
(define-public (submit-proposal 
    (pool-id uint)
    (startup principal)
    (amount uint)
    (description (string-utf8 256)))

    (let
        ((pool (unwrap! (get-pool pool-id) ERR_POOL_NOT_FOUND))
         (new-proposal-id (+ (var-get proposal-counter) u1)))

        ;; Checks
        (asserts! (>= (get total-funds pool) PROPOSAL_THRESHOLD) ERR_BELOW_THRESHOLD)
        (asserts! (<= amount (get total-funds pool)) ERR_INSUFFICIENT_FUNDS)

        ;; Create proposal
        (map-set proposals
            { pool-id: pool-id, proposal-id: new-proposal-id }
            {
                startup: startup,
                amount: amount,
                description: description,
                votes-for: u0,
                votes-against: u0,
                status: u"active",
                created-at: stacks-block-height
            }
        )
        (var-set proposal-counter new-proposal-id)
        (ok new-proposal-id)
    )
)
