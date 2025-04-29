;; TradeSecure: Escrow Contract with Token Support
;; Physical goods escrow system with tracking

;; Import traits
(use-trait sip-010-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ESCROW-NOT-FOUND (err u101))
(define-constant ERR-INVALID-STATE (err u102))
(define-constant ERR-ESCROW-EXPIRED (err u104))
(define-constant ERR-INVALID-TOKEN (err u107))

;; Escrow state constants
(define-constant STATE-CREATED u0)
(define-constant STATE-FUNDED u1)
(define-constant STATE-SHIPPED u2)
(define-constant STATE-DELIVERED u3)
(define-constant STATE-COMPLETED u4)
(define-constant STATE-DISPUTED u5)
(define-constant STATE-REFUNDED u6)
(define-constant STATE-CANCELED u7)

;; Platform fee constants
(define-constant PLATFORM-FEE-PERCENT u2) ;; 2% platform fee
(define-constant FEE-DENOMINATOR u100)
(define-constant PLATFORM-ADDRESS 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE)

;; Data maps and variables
(define-map escrows
  { escrow-id: uint }
  {
    seller: principal,
    buyer: principal,
    amount: uint,
    token-contract: (optional principal),
    description: (string-utf8 500),
    shipping-tracking: (optional (string-ascii 100)),
    state: uint,
    creation-time: uint,
    expiration-time: uint,
    delivery-confirmation-time: (optional uint),
    dispute-resolution-time: (optional uint),
    metadata: (optional (string-utf8 1000))
  }
)

(define-data-var last-escrow-id uint u0)
(define-data-var contract-owner principal tx-sender)

;; Private functions
(define-private (calculate-fee (amount uint))
  (/ (* amount PLATFORM-FEE-PERCENT) FEE-DENOMINATOR)
)

(define-private (calculate-seller-amount (amount uint))
  (- amount (calculate-fee amount))
)

;; Public functions - Escrow Creation and Management

;; Initialize a new STX escrow
(define-public (create-escrow 
  (buyer principal) 
  (amount uint) 
  (description (string-utf8 500)) 
  (expiration-blocks uint)
)
  (let (
    (new-escrow-id (+ (var-get last-escrow-id) u1))
    (current-time block-height)
    (expiration-time (+ current-time expiration-blocks))
  )
    ;; Create the escrow
    (map-set escrows
      { escrow-id: new-escrow-id }
      {
        seller: tx-sender,
        buyer: buyer,
        amount: amount,
        token-contract: none,
        description: description,
        shipping-tracking: none,
        state: STATE-CREATED,
        creation-time: current-time,
        expiration-time: expiration-time,
        delivery-confirmation-time: none,
        dispute-resolution-time: none,
        metadata: none
      }
    )
    
    ;; Update the last escrow ID
    (var-set last-escrow-id new-escrow-id)
    
    ;; Return the new escrow ID
    (ok new-escrow-id)
  )
)

;; Create an escrow with token payment
(define-public (create-token-escrow 
  (buyer principal) 
  (amount uint) 
  (token-contract principal)
  (description (string-utf8 500)) 
  (expiration-blocks uint)
)
  (let (
    (new-escrow-id (+ (var-get last-escrow-id) u1))
    (current-time block-height)
    (expiration-time (+ current-time expiration-blocks))
  )
    ;; Create the escrow
    (map-set escrows
      { escrow-id: new-escrow-id }
      {
        seller: tx-sender,
        buyer: buyer,
        amount: amount,
        token-contract: (some token-contract),
        description: description,
        shipping-tracking: none,
        state: STATE-CREATED,
        creation-time: current-time,
        expiration-time: expiration-time,
        delivery-confirmation-time: none,
        dispute-resolution-time: none,
        metadata: none
      }
    )
    
    ;; Update the last escrow ID
    (var-set last-escrow-id new-escrow-id)
    
    ;; Return the new escrow ID
    (ok new-escrow-id)
  )
)

;; Fund an escrow with STX
(define-public (fund-escrow (escrow-id uint))
  (let (
    (escrow (unwrap! (map-get? escrows { escrow-id: escrow-id }) ERR-ESCROW-NOT-FOUND))
    (amount (get amount escrow))
  )
    ;; Check sender is the buyer
    (asserts! (is-eq tx-sender (get buyer escrow)) ERR-NOT-AUTHORIZED)
    
    ;; Check escrow is in created state
    (asserts! (is-eq (get state escrow) STATE-CREATED) ERR-INVALID-STATE)
    
    ;; Transfer the STX to the contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update escrow state
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow { state: STATE-FUNDED })
    )
    
    (ok true)
  )
)

;; Fund an escrow with tokens
(define-public (fund-token-escrow (escrow-id uint) (token <sip-010-trait>))
  (let (
    (escrow (unwrap! (map-get? escrows { escrow-id: escrow-id }) ERR-ESCROW-NOT-FOUND))
    (amount (get amount escrow))
    (token-contract (unwrap! (get token-contract escrow) ERR-INVALID-TOKEN))
  )
    ;; Check sender is the buyer
    (asserts! (is-eq tx-sender (get buyer escrow)) ERR-NOT-AUTHORIZED)
    
    ;; Check escrow is in created state
    (asserts! (is-eq (get state escrow) STATE-CREATED) ERR-INVALID-STATE)
    
    ;; Verify correct token is being used
    (asserts! (is-eq (contract-of token) token-contract) ERR-INVALID-TOKEN)
    
    ;; Transfer the tokens to the contract
    (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
    
    ;; Update escrow state
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow { state: STATE-FUNDED })
    )
    
    (ok true)
  )
)

;; Mark escrow as shipped
(define-public (ship-escrow (escrow-id uint) (tracking-number (string-ascii 100)))
  (let (
    (escrow (unwrap! (map-get? escrows { escrow-id: escrow-id }) ERR-ESCROW-NOT-FOUND))
  )
    ;; Check sender is the seller
    (asserts! (is-eq tx-sender (get seller escrow)) ERR-NOT-AUTHORIZED)
    
    ;; Check escrow is in funded state
    (asserts! (is-eq (get state escrow) STATE-FUNDED) ERR-INVALID-STATE)
    
    ;; Update escrow state
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow { 
        state: STATE-SHIPPED,
        shipping-tracking: (some tracking-number)
      })
    )
    
    (ok true)
  )
)

;; Manually confirm delivery 
(define-public (confirm-delivery (escrow-id uint))
  (let (
    (escrow (unwrap! (map-get? escrows { escrow-id: escrow-id }) ERR-ESCROW-NOT-FOUND))
  )
    ;; Check sender is the buyer
    (asserts! (is-eq tx-sender (get buyer escrow)) ERR-NOT-AUTHORIZED)
    
    ;; Check escrow is in shipped state
    (asserts! (is-eq (get state escrow) STATE-SHIPPED) ERR-INVALID-STATE)
    
    ;; Update escrow state
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow { 
        state: STATE-DELIVERED,
        delivery-confirmation-time: (some block-height)
      })
    )
    
    (ok true)
  )
)

;; Complete STX escrow and release funds to seller
(define-public (complete-escrow (escrow-id uint))
  (let (
    (escrow (unwrap! (map-get? escrows { escrow-id: escrow-id }) ERR-ESCROW-NOT-FOUND))
    (amount (get amount escrow))
    (seller (get seller escrow))
    (fee (calculate-fee amount))
    (seller-amount (calculate-seller-amount amount))
    (token-contract (get token-contract escrow))
  )
    ;; Check sender is the buyer
    (asserts! (is-eq tx-sender (get buyer escrow)) ERR-NOT-AUTHORIZED)
    
    ;; Check escrow is in delivered state
    (asserts! (is-eq (get state escrow) STATE-DELIVERED) ERR-INVALID-STATE)
    
    ;; Release funds based on whether it's an STX or token escrow
    (if (is-some token-contract)
      ;; It's a token escrow - would call token contract here
      (begin
        ;; Placeholder for token transfer
        (print "Token transfer would happen here")
        (ok true)
      )
      ;; It's an STX escrow
      (begin
        ;; Send fee to platform
        (try! (as-contract (stx-transfer? fee tx-sender PLATFORM-ADDRESS)))
        ;; Send remaining to seller
        (try! (as-contract (stx-transfer? seller-amount tx-sender seller)))
        
        ;; Update escrow state
        (map-set escrows
          { escrow-id: escrow-id }
          (merge escrow { state: STATE-COMPLETED })
        )
        
        (ok true)
      )
    )
  )
)

;; Set contract owner
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Read-only functions

;; Get escrow details
(define-read-only (get-escrow (escrow-id uint))
  (map-get? escrows { escrow-id: escrow-id })
)

;; Get last escrow ID
(define-read-only (get-last-escrow-id)
  (var-get last-escrow-id)
)

;; Get contract owner
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

;; Calculate platform fee for a given amount
(define-read-only (get-platform-fee (amount uint))
  (calculate-fee amount)
)

;; Check if an escrow exists
(define-read-only (escrow-exists (escrow-id uint))
  (is-some (map-get? escrows { escrow-id: escrow-id }))
)
