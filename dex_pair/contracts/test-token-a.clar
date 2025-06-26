;; File: contracts/test-token-a.clar
;; Test SIP-010 Token A for DEX testing

;; Define the SIP-010 trait locally
(define-trait sip010-trait
  ((transfer (uint principal principal (optional (buff 34))) (response bool uint))
   (get-balance (principal) (response uint uint))
   (get-decimals () (response uint uint))
   (get-symbol () (response (string-ascii 32) uint))
   (get-name () (response (string-ascii 32) uint))
   (get-total-supply () (response uint uint))
   (get-token-uri () (response (optional (string-utf8 256)) uint))))

;; Implement the trait
(impl-trait .dex-amm.sip010-trait)

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
