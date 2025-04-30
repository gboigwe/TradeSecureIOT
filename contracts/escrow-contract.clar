;; TradeSecure: Core Escrow Contract (No External Traits)
;; A decentralized escrow system for physical goods leveraging IoT verification
;; Author: An experienced blockchain developer

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ESCROW-NOT-FOUND (err u101))
(define-constant ERR-INVALID-STATE (err u102))
(define-constant ERR-ALREADY-INITIALIZED (err u103))
(define-constant ERR-ESCROW-EXPIRED (err u104))
(define-constant ERR-DEADLINE-PASSED (err u105))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u106))
(define-constant ERR-INVALID-TOKEN (err u107))
(define-constant ERR-UNAUTHORIZED-ORACLE (err u108))

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
    oracle: principal,
    metadata: (optional (string-ascii 1000))  ;; Changed from string-utf8 to string-ascii
  }
)

(define-map oracle-authorizations
  { oracle: principal }
  { authorized: bool }
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

(define-private (is-authorized-oracle (oracle principal))
  (default-to false (get authorized (map-get? oracle-authorizations { oracle: oracle })))
)

(define-private (is-escrow-expired (escrow-id uint))
  (let (
    (escrow (unwrap! (map-get? escrows { escrow-id: escrow-id }) false))
    (current-time block-height)
  )
    (> current-time (get expiration-time escrow))
  )
)

(define-private (validate-escrow-state (escrow-id uint) (expected-state uint))
  (let (
    (escrow (unwrap! (map-get? escrows { escrow-id: escrow-id }) ERR-ESCROW-NOT-FOUND))
  )
    (asserts! (is-eq (get state escrow) expected-state) ERR-INVALID-STATE)
    (asserts! (not (is-escrow-expired escrow-id)) ERR-ESCROW-EXPIRED)
    (ok escrow)
  )
)

;; Public functions - Escrow Creation and Management

;; Initialize a new escrow
(define-public (create-escrow 
  (buyer principal) 
  (amount uint) 
  (description (string-utf8 500)) 
  (expiration-blocks uint)
  (oracle principal)
)
  (let (
    (new-escrow-id (+ (var-get last-escrow-id) u1))
    (current-time block-height)
    (expiration-time (+ current-time expiration-blocks))
  )
    ;; Validate oracle authorization
    (asserts! (is-authorized-oracle oracle) ERR-UNAUTHORIZED-ORACLE)
    
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
        oracle: oracle,
        metadata: none
      }
    )
    
    ;; Update the last escrow ID
    (var-set last-escrow-id new-escrow-id)
    
    ;; Return the new escrow ID
    (ok new-escrow-id)
  )
)

;; Create an escrow with token payment (without using SIP-010 trait)
(define-public (create-token-escrow 
  (buyer principal) 
  (amount uint) 
  (token-contract principal)
  (description (string-utf8 500)) 
  (expiration-blocks uint)
  (oracle principal)
)
  (let (
    (new-escrow-id (+ (var-get last-escrow-id) u1))
    (current-time block-height)
    (expiration-time (+ current-time expiration-blocks))
  )
    ;; Validate oracle authorization
    (asserts! (is-authorized-oracle oracle) ERR-UNAUTHORIZED-ORACLE)
    
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
        oracle: oracle,
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
    (escrow (try! (validate-escrow-state escrow-id STATE-CREATED)))
    (amount (get amount escrow))
  )
    ;; Check sender is the buyer
    (asserts! (is-eq tx-sender (get buyer escrow)) ERR-NOT-AUTHORIZED)
    
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

;; Fund an escrow with tokens - simplified without using trait
;; Note: In production, you would integrate with the actual token contract
(define-public (fund-token-escrow (escrow-id uint))
  (let (
    (escrow (try! (validate-escrow-state escrow-id STATE-CREATED)))
    (amount (get amount escrow))
    (token-contract (unwrap! (get token-contract escrow) ERR-INVALID-TOKEN))
  )
    ;; Check sender is the buyer
    (asserts! (is-eq tx-sender (get buyer escrow)) ERR-NOT-AUTHORIZED)
    
    ;; Note: In a production implementation, you would call the token contract's transfer function
    ;; For development purposes, we'll just update the state
    ;; This simulates a successful token transfer
    
    ;; Update escrow state
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow { state: STATE-FUNDED })
    )
    
    (print {
      action: "token-transfer-simulation",
      token: token-contract,
      amount: amount,
      from: tx-sender,
      to: (as-contract tx-sender)
    })
    
    (ok true)
  )
)

;; Mark escrow as shipped
(define-public (ship-escrow (escrow-id uint) (tracking-number (string-ascii 100)))
  (let (
    (escrow (try! (validate-escrow-state escrow-id STATE-FUNDED)))
  )
    ;; Check sender is the seller
    (asserts! (is-eq tx-sender (get seller escrow)) ERR-NOT-AUTHORIZED)
    
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

;; Confirm delivery via oracle - now using string-ascii to match the map definition
(define-public (confirm-delivery (escrow-id uint) (oracle-data (string-ascii 1000)))
  (let (
    (escrow (unwrap! (map-get? escrows { escrow-id: escrow-id }) ERR-ESCROW-NOT-FOUND))
  )
    ;; Check sender is the authorized oracle
    (asserts! (is-eq tx-sender (get oracle escrow)) ERR-NOT-AUTHORIZED)
    
    ;; Check escrow is in the correct state
    (asserts! (is-eq (get state escrow) STATE-SHIPPED) ERR-INVALID-STATE)
    
    ;; Update escrow state
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow { 
        state: STATE-DELIVERED,
        delivery-confirmation-time: (some block-height),
        metadata: (some oracle-data)
      })
    )
    
    (ok true)
  )
)

;; Complete escrow and release funds to seller
(define-public (complete-escrow (escrow-id uint))
  (let (
    (escrow (try! (validate-escrow-state escrow-id STATE-DELIVERED)))
    (amount (get amount escrow))
    (seller (get seller escrow))
    (fee (calculate-fee amount))
    (seller-amount (calculate-seller-amount amount))
    (token-contract (get token-contract escrow))
  )
    ;; Check sender is the buyer or this is an automatic completion after delivery confirmation
    (asserts! (or 
      (is-eq tx-sender (get buyer escrow))
      ;; Automatic completion after 3 days (432 blocks, approx. 3 days at 10-minute blocks)
      (match (get delivery-confirmation-time escrow)
        confirmation-time (> block-height (+ confirmation-time u432))
        false
      )
    ) ERR-NOT-AUTHORIZED)
    
    ;; Handle based on payment type
    (match token-contract
      token-principal
        ;; For token escrows - in production, would call the token contract
        (begin
          (print {
            action: "token-release-simulation",
            token: token-principal,
            fee-amount: fee,
            fee-to: PLATFORM-ADDRESS,
            seller-amount: seller-amount,
            seller: seller
          })
          
          ;; Update escrow state
          (map-set escrows
            { escrow-id: escrow-id }
            (merge escrow { state: STATE-COMPLETED })
          )
          
          (ok true)
        )
      ;; For STX escrows
      (as-contract
        (begin
          ;; Send fee to platform
          (try! (stx-transfer? fee tx-sender PLATFORM-ADDRESS))
          ;; Send remaining to seller
          (try! (stx-transfer? seller-amount tx-sender seller))
          
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
)

;; Initiate dispute - changed to use string-ascii to match the metadata field type
(define-public (dispute-escrow (escrow-id uint) (dispute-reason (string-ascii 500)))
  (let (
    (escrow (unwrap! (map-get? escrows { escrow-id: escrow-id }) ERR-ESCROW-NOT-FOUND))
    (current-state (get state escrow))
  )
    ;; Check sender is the buyer
    (asserts! (is-eq tx-sender (get buyer escrow)) ERR-NOT-AUTHORIZED)
    
    ;; Check escrow is in a disputeable state
    (asserts! (or 
      (is-eq current-state STATE-FUNDED) 
      (is-eq current-state STATE-SHIPPED)
      (is-eq current-state STATE-DELIVERED)
    ) ERR-INVALID-STATE)
    
    ;; Update escrow state
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow { 
        state: STATE-DISPUTED,
        dispute-resolution-time: (some block-height),
        metadata: (some dispute-reason)
      })
    )
    
    (ok true)
  )
)

;; Resolve dispute and refund buyer
(define-public (resolve-dispute-refund (escrow-id uint))
  (let (
    (escrow (unwrap! (map-get? escrows { escrow-id: escrow-id }) ERR-ESCROW-NOT-FOUND))
    (amount (get amount escrow))
    (buyer (get buyer escrow))
    (token-contract (get token-contract escrow))
  )
    ;; Check sender is the contract owner (arbiter)
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    ;; Check escrow is in disputed state
    (asserts! (is-eq (get state escrow) STATE-DISPUTED) ERR-INVALID-STATE)
    
    ;; Handle based on payment type
    (match token-contract
      token-principal
        ;; For token escrows - in production, would call the token contract
        (begin
          (print {
            action: "token-refund-simulation",
            token: token-principal,
            amount: amount,
            buyer: buyer
          })
          
          ;; Update escrow state
          (map-set escrows
            { escrow-id: escrow-id }
            (merge escrow { state: STATE-REFUNDED })
          )
          
          (ok true)
        )
      ;; For STX escrows
      (as-contract
        (begin
          ;; Refund full amount to buyer
          (try! (stx-transfer? amount tx-sender buyer))
          
          ;; Update escrow state
          (map-set escrows
            { escrow-id: escrow-id }
            (merge escrow { state: STATE-REFUNDED })
          )
          
          (ok true)
        )
      )
    )
  )
)

;; Resolve dispute in seller's favor
(define-public (resolve-dispute-release (escrow-id uint))
  (let (
    (escrow (unwrap! (map-get? escrows { escrow-id: escrow-id }) ERR-ESCROW-NOT-FOUND))
    (amount (get amount escrow))
    (seller (get seller escrow))
    (fee (calculate-fee amount))
    (seller-amount (calculate-seller-amount amount))
    (token-contract (get token-contract escrow))
  )
    ;; Check sender is the contract owner (arbiter)
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    ;; Check escrow is in disputed state
    (asserts! (is-eq (get state escrow) STATE-DISPUTED) ERR-INVALID-STATE)
    
    ;; Handle based on payment type
    (match token-contract
      token-principal
        ;; For token escrows - in production, would call the token contract
        (begin
          (print {
            action: "token-release-simulation",
            token: token-principal,
            fee-amount: fee,
            fee-to: PLATFORM-ADDRESS,
            seller-amount: seller-amount,
            seller: seller
          })
          
          ;; Update escrow state
          (map-set escrows
            { escrow-id: escrow-id }
            (merge escrow { state: STATE-COMPLETED })
          )
          
          (ok true)
        )
      ;; For STX escrows
      (as-contract
        (begin
          ;; Send fee to platform
          (try! (stx-transfer? fee tx-sender PLATFORM-ADDRESS))
          ;; Send remaining to seller
          (try! (stx-transfer? seller-amount tx-sender seller))
          
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
)

;; Cancel escrow (before it's funded)
(define-public (cancel-escrow (escrow-id uint))
  (let (
    (escrow (unwrap! (map-get? escrows { escrow-id: escrow-id }) ERR-ESCROW-NOT-FOUND))
  )
    ;; Check escrow is in created state
    (asserts! (is-eq (get state escrow) STATE-CREATED) ERR-INVALID-STATE)
    
    ;; Check sender is the seller
    (asserts! (is-eq tx-sender (get seller escrow)) ERR-NOT-AUTHORIZED)
    
    ;; Update escrow state
    (map-set escrows
      { escrow-id: escrow-id }
      (merge escrow { state: STATE-CANCELED })
    )
    
    (ok true)
  )
)

;; Admin functions

;; Set contract owner
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Authorize an oracle
(define-public (authorize-oracle (oracle principal) (authorized bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (map-set oracle-authorizations { oracle: oracle } { authorized: authorized })
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

;; Check if an oracle is authorized
(define-read-only (is-oracle-authorized (oracle principal))
  (is-authorized-oracle oracle)
)

;; Calculate platform fee for a given amount
(define-read-only (get-platform-fee (amount uint))
  (calculate-fee amount)
)

;; Check if an escrow exists
(define-read-only (escrow-exists (escrow-id uint))
  (is-some (map-get? escrows { escrow-id: escrow-id }))
)

;; Create a descriptive state string from the numeric state
(define-read-only (get-escrow-state-string (state uint))
  (if (is-eq state STATE-CREATED)
    "Created"
    (if (is-eq state STATE-FUNDED)
      "Funded"
      (if (is-eq state STATE-SHIPPED)
        "Shipped"
        (if (is-eq state STATE-DELIVERED)
          "Delivered"
          (if (is-eq state STATE-COMPLETED)
            "Completed"
            (if (is-eq state STATE-DISPUTED)
              "Disputed"
              (if (is-eq state STATE-REFUNDED)
                "Refunded"
                (if (is-eq state STATE-CANCELED)
                  "Canceled"
                  "Unknown"
                )
              )
            )
          )
        )
      )
    )
  )
)
