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


;; Vote on proposal
(define-public (vote (pool-id uint) (proposal-id uint) (vote-for bool))
    (let
        ((proposal (unwrap! (get-proposal pool-id proposal-id) ERR_POOL_NOT_FOUND))
         (contribution (unwrap! (get-contribution pool-id tx-sender) ERR_NOT_AUTHORIZED))
         (voting-power (get amount contribution)))

        ;; Checks
        (asserts! (is-eq (get status proposal) u"active") ERR_VOTING_CLOSED)
        (asserts! (is-none (get-vote pool-id proposal-id tx-sender)) ERR_ALREADY_VOTED)

        ;; Record vote
        (map-set votes
            { pool-id: pool-id, proposal-id: proposal-id, voter: tx-sender }
            { vote: vote-for }
        )

        ;; Update proposal votes
        (map-set proposals
            { pool-id: pool-id, proposal-id: proposal-id }
            (merge proposal {
                votes-for: (if vote-for 
                    (+ (get votes-for proposal) voting-power)
                    (get votes-for proposal)),
                votes-against: (if vote-for
                    (get votes-against proposal)
                    (+ (get votes-against proposal) voting-power))
            })
        )
        (ok true)
    )
)

;; Execute proposal
(define-public (execute-proposal (pool-id uint) (proposal-id uint))
    (let
        ((proposal (unwrap! (get-proposal pool-id proposal-id) ERR_POOL_NOT_FOUND))
         (pool (unwrap! (get-pool pool-id) ERR_POOL_NOT_FOUND)))

        ;; Checks
        (asserts! (is-eq (get status proposal) u"active") ERR_VOTING_CLOSED)
        (asserts! (>= (- stacks-block-height (get created-at proposal)) VOTING_PERIOD) ERR_VOTING_CLOSED)

        ;; Check if proposal passed
        (if (> (get votes-for proposal) (get votes-against proposal))
            (begin
                ;; Transfer funds to startup
                (try! (as-contract (stx-transfer? 
                    (get amount proposal)
                    (as-contract tx-sender)
                    (get startup proposal))))

                ;; Update proposal status
                (map-set proposals
                    { pool-id: pool-id, proposal-id: proposal-id }
                    (merge proposal { status: u"executed" })
                )
                (ok true)
            )
            (begin
                ;; Update proposal status
                (map-set proposals
                    { pool-id: pool-id, proposal-id: proposal-id }
                    (merge proposal { status: u"rejected" })
                )
                (ok false)
            )
        )
    )
)

;; Set pool metadata
(define-public (set-pool-metadata 
    (pool-id uint)
    (name (string-utf8 64))
    (description (string-utf8 256))
    (category (string-utf8 64))
    (logo-uri (string-utf8 256)))

    (let
        ((pool (unwrap! (get-pool pool-id) ERR_POOL_NOT_FOUND)))

        ;; Check if caller is the pool creator
        (asserts! (is-eq tx-sender (get creator pool)) ERR_NOT_AUTHORIZED)

        ;; Validate inputs
        (asserts! (> (len name) u0) ERR_INVALID_METADATA)
        (asserts! (> (len description) u0) ERR_INVALID_METADATA)

        ;; Set metadata
        (ok (map-set pool-metadata
            { pool-id: pool-id }
            {
                name: name,
                description: description,
                category: category,
                logo-uri: logo-uri
            }
        ))
    )
)

;; Get pool metadata
(define-read-only (get-pool-metadata (pool-id uint))
    (map-get? pool-metadata { pool-id: pool-id })
)

;; Search pools by category
(define-read-only (get-pools-by-category (category (string-utf8 64)) (limit uint))
    (ok u"Implementation would require off-chain indexing")
)

;; FEATURE 2: Staking & Rewards System

;; Set reward rate (only contract owner)
(define-public (set-reward-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (ok (var-set reward-rate new-rate))
    )
)

;; Stake contribution in a pool
(define-public (stake-contribution (pool-id uint) (amount uint))
    (let
        ((pool (unwrap! (get-pool pool-id) ERR_POOL_NOT_FOUND))
         (contribution (unwrap! (get-contribution pool-id tx-sender) ERR_NOT_AUTHORIZED))
         (existing-stake (get-staking-info pool-id tx-sender)))

        ;; Checks
        (asserts! (get active pool) ERR_POOL_NOT_FOUND)
        (asserts! (<= amount (get amount contribution)) ERR_INSUFFICIENT_FUNDS)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)

        ;; If already staking, claim rewards first
        (if (is-some existing-stake)
            (try! (claim-staking-rewards pool-id))
            true)

        ;; Set or update staking info
        (ok (map-set staking-info
            { pool-id: pool-id, staker: tx-sender }
            {
                staked-amount: (+ (default-to u0 (get staked-amount existing-stake)) amount),
                staked-at: stacks-block-height,
                last-reward-claim: stacks-block-height
            }
        ))
    )
)

;; Get staking information
(define-read-only (get-staking-info (pool-id uint) (staker principal))
    (map-get? staking-info { pool-id: pool-id, staker: staker })
)

;; Calculate pending rewards
(define-read-only (get-pending-rewards (pool-id uint))
    (let
        ((stake-data (unwrap! (get-staking-info pool-id tx-sender) ERR_STAKE_NOT_FOUND)))

        (let
            ((blocks-staked (- stacks-block-height (get last-reward-claim stake-data)))
             (staked-amount (get staked-amount stake-data))
             (base-reward (* blocks-staked (var-get reward-rate))))

            (ok (* base-reward staked-amount))
        )
    )
)