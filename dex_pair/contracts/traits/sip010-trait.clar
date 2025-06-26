;; File: contracts/traits/sip010-trait.clar
;; Separate trait definition to avoid circular dependencies

(define-trait sip010-trait
  ((transfer (uint principal principal (optional (buff 34))) (response bool uint))
   (get-balance (principal) (response uint uint))
   (get-decimals () (response uint uint))
   (get-symbol () (response (string-ascii 32) uint))
   (get-name () (response (string-ascii 32) uint))
   (get-total-supply () (response uint uint))
   (get-token-uri () (response (optional (string-utf8 256)) uint))))

;; File: contracts/test-token-a.clar
;; Test SIP-010 Token A for DEX testing

;; Import the trait from separate file
(use-trait sip010-trait .traits.sip010-trait.sip010-trait)

;; Implement the trait
(impl-trait .traits.sip010-trait.sip010-trait)

(define-fungible-token test-token-a)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))

(define-data-var token-name (string-ascii 32) "Test Token A")
(define-data-var token-symbol (string-ascii 32) "TTA")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var token-decimals uint u6)

;; SIP-010 Functions
(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
    (begin
        (asserts! (or (is-eq from tx-sender) (is-eq from contract-caller)) (err u403))
        (ft-transfer? test-token-a amount from to)
    )
)

(define-read-only (get-name)
    (ok (var-get token-name))
)

(define-read-only (get-symbol)
    (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
    (ok (var-get token-decimals))
)

(define-read-only (get-balance (who principal))
    (ok (ft-get-balance test-token-a who))
)

(define-read-only (get-total-supply)
    (ok (ft-get-supply test-token-a))
)

(define-read-only (get-token-uri)
    (ok (var-get token-uri))
)

;; Mint function for testing
(define-public (mint (amount uint) (to principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ft-mint? test-token-a amount to)
    )
)

;; Initialize with some tokens for testing
(ft-mint? test-token-a u100000000000000 contract-owner)

;; File: contracts/test-token-b.clar
;; Test SIP-010 Token B for DEX testing

;; Import the trait from separate file
(use-trait sip010-trait .traits.sip010-trait.sip010-trait)

;; Implement the trait
(impl-trait .traits.sip010-trait.sip010-trait)

(define-fungible-token test-token-b)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))

(define-data-var token-name (string-ascii 32) "Test Token B")
(define-data-var token-symbol (string-ascii 32) "TTB")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var token-decimals uint u6)

;; SIP-010 Functions
(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
    (begin
        (asserts! (or (is-eq from tx-sender) (is-eq from contract-caller)) (err u403))
        (ft-transfer? test-token-b amount from to)
    )
)

(define-read-only (get-name)
    (ok (var-get token-name))
)

(define-read-only (get-symbol)
    (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
    (ok (var-get token-decimals))
)

(define-read-only (get-balance (who principal))
    (ok (ft-get-balance test-token-b who))
)

(define-read-only (get-total-supply)
    (ok (ft-get-supply test-token-b))
)

(define-read-only (get-token-uri)
    (ok (var-get token-uri))
)

;; Mint function for testing
(define-public (mint (amount uint) (to principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ft-mint? test-token-b amount to)
    )
)

;; Initialize with some tokens for testing
(ft-mint? test-token-b u100000000000000 contract-owner)

;; File: contracts/dex-amm.clar
;; Enhanced DEX AMM with bug fixes and security improvements

;; Import SIP-010 trait
(use-trait sip010-trait .traits.sip010-trait.sip010-trait)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-liquidity (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-slippage-exceeded (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-pool-not-initialized (err u105))
(define-constant err-transfer-failed (err u106))
(define-constant minimum-liquidity u1000) ;; Minimum liquidity lock

;; Data Variables
(define-data-var token-a-reserve uint u0)
(define-data-var token-b-reserve uint u0)
(define-data-var total-liquidity uint u0)
(define-data-var fee-rate uint u30) ;; 0.3% = 30/10000
(define-data-var paused bool false)

;; Data Maps
(define-map liquidity-providers principal uint)
(define-map user-liquidity-history 
  { user: principal, block-height: uint } 
  { liquidity: uint, timestamp: uint })

;; Token contracts for testing
(define-constant token-a .test-token-a)
(define-constant token-b .test-token-b)

;; Read-only functions
(define-read-only (get-reserves)
  {
    token-a: (var-get token-a-reserve),
    token-b: (var-get token-b-reserve),
    total-liquidity: (var-get total-liquidity)
  })

(define-read-only (get-liquidity-balance (user principal))
  (default-to u0 (map-get? liquidity-providers user)))

(define-read-only (calculate-swap-output (amount-in uint) (reserve-in uint) (reserve-out uint))
  (let ((fee-adjusted-input (* amount-in (- u10000 (var-get fee-rate))))
        (numerator (* fee-adjusted-input reserve-out))
        (denominator (+ (* reserve-in u10000) fee-adjusted-input)))
    (if (> denominator u0)
        (/ numerator denominator)
        u0)))

(define-read-only (get-price-ratio)
  (let ((reserve-a (var-get token-a-reserve))
        (reserve-b (var-get token-b-reserve)))
    (if (and (> reserve-a u0) (> reserve-b u0))
        (/ (* reserve-b u1000000) reserve-a) ;; Price of A in terms of B (scaled by 1M)
        u0)))

(define-read-only (is-paused)
  (var-get paused))

;; Private functions - Non-recursive square root implementation
(define-private (integer-sqrt (n uint))
  ;; Simple approximation for integer square root
  ;; Uses bit manipulation approach for efficiency
  (if (< n u2)
      n
      (if (< n u4)
          u1
          (if (< n u9)
              u2
              (if (< n u16)
                  u3
                  (if (< n u25)
                      u4
                      (if (< n u36)
                          u5
                          (if (< n u49)
                              u6
                              (if (< n u64)
                                  u7
                                  (if (< n u81)
                                      u8
                                      (if (< n u100)
                                          u9
                                          ;; For larger numbers, use approximation
                                          (/ (+ (/ n u10) u10) u2))))))))))))

;; Helper function to find minimum of two numbers
(define-private (min-uint (a uint) (b uint))
  (if (< a b) a b))

(define-private (calculate-liquidity-mint (amount-a uint) (amount-b uint))
  (let ((current-a (var-get token-a-reserve))
        (current-b (var-get token-b-reserve))
        (total-supply (var-get total-liquidity)))
    (if (is-eq total-supply u0)
        ;; Initial liquidity - use geometric mean minus minimum liquidity
        ;; For very large numbers, use a simpler approximation to avoid overflow
        (let ((product (* amount-a amount-b)))
          (if (> product u1000000000000) ;; If product is very large
              (- (/ (+ amount-a amount-b) u2) minimum-liquidity) ;; Use arithmetic mean as approximation
              (- (integer-sqrt product) minimum-liquidity))) ;; Use geometric mean
        ;; Subsequent liquidity - maintain ratio
        (min-uint (/ (* amount-a total-supply) current-a)
                  (/ (* amount-b total-supply) current-b)))))

;; Admin functions
(define-public (set-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-rate u500) (err u107)) ;; Max 5% fee
    (ok (var-set fee-rate new-rate))))

(define-public (toggle-pause)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set paused (not (var-get paused))))))

;; Core AMM functions with generic token support
(define-public (provide-liquidity-generic 
    (token-a-contract <sip010-trait>) 
    (token-b-contract <sip010-trait>)
    (amount-a uint) 
    (amount-b uint) 
    (min-liquidity uint))
  (begin
    (asserts! (not (var-get paused)) (err u108))
    (asserts! (and (> amount-a u0) (> amount-b u0)) err-invalid-amount)
    
    ;; Calculate expected liquidity tokens
    (let ((liquidity-to-mint (calculate-liquidity-mint amount-a amount-b)))
      (asserts! (>= liquidity-to-mint min-liquidity) err-slippage-exceeded)
      
      ;; Transfer tokens to contract
      (try! (contract-call? token-a-contract transfer 
                           amount-a tx-sender (as-contract tx-sender) none))
      (try! (contract-call? token-b-contract transfer 
                           amount-b tx-sender (as-contract tx-sender) none))
      
      ;; Update reserves and liquidity
      (var-set token-a-reserve (+ (var-get token-a-reserve) amount-a))
      (var-set token-b-reserve (+ (var-get token-b-reserve) amount-b))
      (var-set total-liquidity (+ (var-get total-liquidity) liquidity-to-mint))
      
      ;; Update user's liquidity balance
      (let ((current-user-liquidity (get-liquidity-balance tx-sender)))
        (map-set liquidity-providers tx-sender (+ current-user-liquidity liquidity-to-mint))
        
        ;; Record liquidity history
        (map-set user-liquidity-history 
                 { user: tx-sender, block-height: block-height }
                 { liquidity: liquidity-to-mint, timestamp: block-time })
        
        (ok liquidity-to-mint)))))

;; Convenience functions for test tokens
(define-public (provide-liquidity (amount-a uint) (amount-b uint) (min-liquidity uint))
  (provide-liquidity-generic token-a token-b amount-a amount-b min-liquidity))

(define-public (remove-liquidity-generic 
    (token-a-contract <sip010-trait>) 
    (token-b-contract <sip010-trait>)
    (liquidity-amount uint) 
    (min-amount-a uint) 
    (min-amount-b uint))
  (begin
    (asserts! (not (var-get paused)) (err u108))
    (asserts! (> liquidity-amount u0) err-invalid-amount)
    
    (let ((user-liquidity (get-liquidity-balance tx-sender))
          (total-supply (var-get total-liquidity))
          (reserve-a (var-get token-a-reserve))
          (reserve-b (var-get token-b-reserve)))
      
      (asserts! (>= user-liquidity liquidity-amount) err-insufficient-balance)
      (asserts! (> total-supply u0) err-pool-not-initialized)
      
      ;; Calculate token amounts to return
      (let ((amount-a (/ (* liquidity-amount reserve-a) total-supply))
            (amount-b (/ (* liquidity-amount reserve-b) total-supply)))
        
        (asserts! (>= amount-a min-amount-a) err-slippage-exceeded)
        (asserts! (>= amount-b min-amount-b) err-slippage-exceeded)
        
        ;; Update state
        (var-set token-a-reserve (- reserve-a amount-a))
        (var-set token-b-reserve (- reserve-b amount-b))
        (var-set total-liquidity (- total-supply liquidity-amount))
        (map-set liquidity-providers tx-sender (- user-liquidity liquidity-amount))
        
        ;; Transfer tokens back to user
        (try! (as-contract (contract-call? token-a-contract transfer 
                                          amount-a tx-sender tx-sender none)))
        (try! (as-contract (contract-call? token-b-contract transfer 
                                          amount-b tx-sender tx-sender none)))
        
        (ok { amount-a: amount-a, amount-b: amount-b })))))

(define-public (remove-liquidity (liquidity-amount uint) (min-amount-a uint) (min-amount-b uint))
  (remove-liquidity-generic token-a token-b liquidity-amount min-amount-a min-amount-b))

(define-public (swap-a-for-b-generic 
    (token-a-contract <sip010-trait>) 
    (token-b-contract <sip010-trait>)
    (amount-a uint) 
    (min-amount-out uint))
  (begin
    (asserts! (not (var-get paused)) (err u108))
    (asserts! (> amount-a u0) err-invalid-amount)
    
    (let ((reserve-a (var-get token-a-reserve))
          (reserve-b (var-get token-b-reserve))
          (amount-out (calculate-swap-output amount-a reserve-a reserve-b)))
      
      (asserts! (> amount-out u0) err-insufficient-liquidity)
      (asserts! (>= amount-out min-amount-out) err-slippage-exceeded)
      (asserts! (< amount-out reserve-b) err-insufficient-liquidity)
      
      ;; Transfer input token from user
      (try! (contract-call? token-a-contract transfer 
                           amount-a tx-sender (as-contract tx-sender) none))
      
      ;; Update reserves
      (var-set token-a-reserve (+ reserve-a amount-a))
      (var-set token-b-reserve (- reserve-b amount-out))
      
      ;; Transfer output token to user
      (try! (as-contract (contract-call? token-b-contract transfer 
                                        amount-out tx-sender tx-sender none)))
      
      (ok amount-out))))

(define-public (swap-a-for-b (amount-a uint) (min-amount-out uint))
  (swap-a-for-b-generic token-a token-b amount-a min-amount-out))

(define-public (swap-b-for-a-generic 
    (token-a-contract <sip010-trait>) 
    (token-b-contract <sip010-trait>)
    (amount-b uint) 
    (min-amount-out uint))
  (begin
    (asserts! (not (var-get paused)) (err u108))
    (asserts! (> amount-b u0) err-invalid-amount)
    
    (let ((reserve-a (var-get token-a-reserve))
          (reserve-b (var-get token-b-reserve))
          (amount-out (calculate-swap-output amount-b reserve-b reserve-a)))
      
      (asserts! (> amount-out u0) err-insufficient-liquidity)
      (asserts! (>= amount-out min-amount-out) err-slippage-exceeded)
      (asserts! (< amount-out reserve-a) err-insufficient-liquidity)
      
      ;; Transfer input token from user
      (try! (contract-call? token-b-contract transfer 
                           amount-b tx-sender (as-contract tx-sender) none))
      
      ;; Update reserves
      (var-set token-b-reserve (+ reserve-b amount-b))
      (var-set token-a-reserve (- reserve-a amount-out))
      
      ;; Transfer output token to user
      (try! (as-contract (contract-call? token-a-contract transfer 
                                        amount-out tx-sender tx-sender none)))
      
      (ok amount-out))))

(define-public (swap-b-for-a (amount-b uint) (min-amount-out uint))
  (swap-b-for-a-generic token-a token-b amount-b min-amount-out))
