(define-trait sip010-trait
  ((transfer (uint principal principal) (response bool uint))
   (get-balance (principal) (response uint uint))
   (get-decimals () (response uint uint))
   (get-symbol () (response (string-ascii 32) uint))
   (get-name () (response (string-ascii 32) uint))))

(define-data-var token-a-reserve uint u0)
(define-data-var token-b-reserve uint u0)
(define-data-var total-liquidity uint u0)
(define-map liquidity-providers { user: principal } uint)

(define-constant token-a 'SP...token-a)
(define-constant token-b 'SP...token-b)

(define-read-only (get-reserves)
  {
    token-a: (var-get token-a-reserve),
    token-b: (var-get token-b-reserve)
  })

(define-public (provide-liquidity (amount-a uint) (amount-b uint))
  (begin
    ;; Transfer token A
    (try! (contract-call? token-a transfer amount-a tx-sender contract-principal))
    ;; Transfer token B
    (try! (contract-call? token-b transfer amount-b tx-sender contract-principal))

    (let ((current-a (var-get token-a-reserve))
          (current-b (var-get token-b-reserve))
          (liquidity (if (is-eq (var-get total-liquidity) u0)
                         (sqrt (* amount-a amount-b))
                         (min (* amount-a (var-get total-liquidity)) / current-a
                              (* amount-b (var-get total-liquidity)) / current-b))))

      (var-set token-a-reserve (+ current-a amount-a))
      (var-set token-b-reserve (+ current-b amount-b))
      (var-set total-liquidity (+ (var-get total-liquidity) liquidity))
      (map-set liquidity-providers { user: tx-sender } liquidity)
      (ok liquidity)))

(define-public (swap-a-for-b (amount-a uint))
  (begin
    (try! (contract-call? token-a transfer amount-a tx-sender contract-principal))
    (let ((a-reserve (var-get token-a-reserve))
          (b-reserve (var-get token-b-reserve))
          (amount-in-with-fee (* amount-a u997)) ;; 0.3% fee
          (numerator (* amount-in-with-fee b-reserve))
          (denominator (+ (* a-reserve u1000) amount-in-with-fee))
          (amount-out (/ numerator denominator)))
      (asserts! (< amount-out b-reserve) (err u900))
      (var-set token-a-reserve (+ a-reserve amount-a))
      (var-set token-b-reserve (- b-reserve amount-out))
      (try! (contract-call? token-b transfer amount-out contract-principal tx-sender))
      (ok amount-out))))
