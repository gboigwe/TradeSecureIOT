;; TradeSecure: Escrow Contract with Payment Functions
;; Physical goods escrow system with tracking

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ESCROW-NOT-FOUND (err u101))
(define-constant ERR-INVALID-STATE (err u102))

;; State constants
(define-constant STATE-CREATED u0)
(define-constant STATE-FUNDED u1)
(define-constant STATE-SHIPPED u2)
(define-constant STATE-DELIVERED u3)
(define-constant STATE-COMPLETED u4)

;; Fee constants
(define-constant PLATFORM-FEE-PERCENT u2) ;; 2% platform fee
(define-constant FEE-DENOMINATOR u100)
(define-constant PLATFORM-ADDRESS 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE)

;; Escrow data structure
(define-map escrows
  { escrow-id: uint }
  {
    seller: principal,
    buyer: principal,
    amount: uint,
    description: (string-ascii 100),
    shipping-tracking: (optional (string-ascii 100)),
    state: uint,
    creation-time: uint
  }
)

(define-data-var last-escrow-id uint u0)

;; Private fee calculation functions
(define-private (calculate-fee (amount uint))
  (/ (* amount PLATFORM-FEE-PERCENT) FEE-DENOMINATOR)
)

(define-private (calculate-seller-amount (amount uint))
  (- amount (calculate-fee amount))
)

;; Create escrow
(define-public (create-escrow (buyer principal) (amount uint) (description (string-ascii 100)))
  (let (
    (new-escrow-id (+ (var-get last-escrow-id) u1))
    (current-time block-height)
  )
    (map-set escrows
      { escrow-id: new-escrow-id }
      {
        seller: tx-sender,
        buyer: buyer,
        amount: amount,
        description: description,
        shipping-tracking: none,
        state: STATE-CREATED,
        creation-time: current-time
      }
    )
    (var-set last-escrow-id new-escrow-id)
    (ok new-escrow-id)
  )
)

;; Fund escrow with STX
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

;; Mark escrow as delivered (basic function, will be enhanced with oracle)
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
      (merge escrow { state: STATE-DELIVERED })
    )
    
    (ok true)
  )
)

;; Complete escrow and release funds to seller
(define-public (complete-escrow (escrow-id uint))
  (let (
    (escrow (unwrap! (map-get? escrows { escrow-id: escrow-id }) ERR-ESCROW-NOT-FOUND))
    (amount (get amount escrow))
    (seller (get seller escrow))
    (fee (calculate-fee amount))
    (seller-amount (calculate-seller-amount amount))
  )
    ;; Check sender is the buyer
    (asserts! (is-eq tx-sender (get buyer escrow)) ERR-NOT-AUTHORIZED)
    
    ;; Check escrow is in delivered state
    (asserts! (is-eq (get state escrow) STATE-DELIVERED) ERR-INVALID-STATE)
    
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

;; Read-only functions

;; Get escrow details
(define-read-only (get-escrow (escrow-id uint))
  (map-get? escrows { escrow-id: escrow-id })
)

;; Get last escrow ID
(define-read-only (get-last-escrow-id)
  (var-get last-escrow-id)
)
