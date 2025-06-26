;; File: contracts/dex-governance.clar
;; Governance contract for DEX AMM parameter management

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-enough-votes (err u201))
(define-constant err-proposal-not-found (err u202))
(define-constant err-proposal-expired (err u203))
(define-constant err-already-voted (err u204))
(define-constant err-proposal-not-active (err u205))
(define-constant err-insufficient-stake (err u206))

;; Governance parameters
(define-constant voting-period u1008) ;; ~1 week in blocks
(define-constant min-proposal-stake u1000000) ;; 1M tokens required to propose
(define-constant quorum-threshold u20) ;; 20% of total staked tokens

;; Data variables
(define-data-var proposal-counter uint u0)
(define-data-var total-staked uint u0)

;; Proposal structure
(define-map proposals
  uint
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    target-contract: principal,
    function-name: (string-ascii 50),
    parameters: (list 5 uint),
    start-block: uint,
    end-block: uint,
    votes-for: uint,
    votes-against: uint,
    executed: bool,
    stake-amount: uint
  })

;; User stakes for governance
(define-map user-stakes principal uint)

;; Voting records
(define-map votes 
  { proposal-id: uint, voter: principal }
  { vote: bool, voting-power: uint })

;; Proposal creation
(define-public (create-proposal 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (target-contract principal)
  (function-name (string-ascii 50))
  (parameters (list 5 uint))
  (stake-amount uint))
  (begin
    (asserts! (>= stake-amount min-proposal-stake) err-insufficient-stake)
    
    ;; Transfer stake to contract
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    (let ((proposal-id (+ (var-get proposal-counter) u1))
          (start-block (+ block-height u1))
          (end-block (+ block-height voting-period)))
      
      (map-set proposals proposal-id
        {
          proposer: tx-sender,
          title: title,
          description: description,
          target-contract: target-contract,
          function-name: function-name,
          parameters: parameters,
          start-block: start-block,
          end-block: end-block,
          votes-for: u0,
          votes-against: u0,
          executed: false,
          stake-amount: stake-amount
        })
      
      (var-set proposal-counter proposal-id)
      (ok proposal-id))))

;; Stake tokens for voting power
(define-public (stake-tokens (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (let ((current-stake (default-to u0 (map-get? user-stakes tx-sender))))
      (map-set user-stakes tx-sender (+ current-stake amount))
      (var-set total-staked (+ (var-get total-staked) amount))
      (ok (+ current-stake amount)))))

;; Unstake tokens (can only unstake if no active votes)
(define-public (unstake-tokens (amount uint))
  (let ((current-stake (default-to u0 (map-get? user-stakes tx-sender))))
    (asserts! (>= current-stake amount) (err u207))
    (map-set user-stakes tx-sender (- current-stake amount))
    (var-set total-staked (- (var-get total-staked) amount))
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (ok (- current-stake amount))))

;; Vote on proposal
(define-public (vote (proposal-id uint) (vote-for bool))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
        (voting-power (default-to u0 (map-get? user-stakes tx-sender))))
    
    (asserts! (> voting-power u0) err-insufficient-stake)
    (asserts! (>= block-height (get start-block proposal)) err-proposal-not-active)
    (asserts! (<= block-height (get end-block proposal)) err-proposal-expired)
    (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: tx-sender })) err-already-voted)
    
    ;; Record vote
    (map-set votes 
      { proposal-id: proposal-id, voter: tx-sender }
      { vote: vote-for, voting-power: voting-power })
    
    ;; Update proposal vote counts
    (if vote-for
        (map-set proposals proposal-id
          (merge proposal { votes-for: (+ (get votes-for proposal) voting-power) }))
        (map-set proposals proposal-id
          (merge proposal { votes-against: (+ (get votes-against proposal) voting-power) })))
    
    (ok true)))

;; Execute proposal if it passes
(define-public (execute-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found)))
    (asserts! (> block-height (get end-block proposal)) err-proposal-not-active)
    (asserts! (not (get executed proposal)) (err u208))
    
    (let ((total-votes (+ (get votes-for proposal) (get votes-against proposal)))
          (quorum-required (/ (* (var-get total-staked) quorum-threshold) u100)))
      
      (asserts! (>= total-votes quorum-required) err-not-enough-votes)
      (asserts! (> (get votes-for proposal) (get votes-against proposal)) err-not-enough-votes)
      
      ;; Mark as executed
      (map-set proposals proposal-id
        (merge proposal { executed: true }))
      
      ;; Return stake to proposer
      (try! (as-contract (stx-transfer? (get stake-amount proposal) 
                                       tx-sender (get proposer proposal))))
      
      (ok true))))

;; Read-only functions
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id))

(define-read-only (get-voting-power (user principal))
  (default-to u0 (map-get? user-stakes user)))

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter }))

(define-read-only (get-governance-stats)
  {
    total-proposals: (var-get proposal-counter),
    total-staked: (var-get total-staked),
    quorum-threshold: quorum-threshold,
    voting-period: voting-period
  })
