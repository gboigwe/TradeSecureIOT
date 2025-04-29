;; TradeSecure: Initial Escrow Contract Framework
;; Physical goods escrow system with tracking

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))

;; State constants
(define-constant STATE-CREATED u0)
(define-constant STATE-FUNDED u1)
(define-constant STATE-SHIPPED u2)
(define-constant STATE-DELIVERED u3)
(define-constant STATE-COMPLETED u4)

;; Basic escrow data structure
(define-map escrows
  { escrow-id: uint }
  {
    seller: principal,
    buyer: principal,
    amount: uint,
    description: (string-ascii 100),
    state: uint
  }
)

(define-data-var last-escrow-id uint u0)

;; Basic escrow creation function
(define-public (create-escrow (buyer principal) (amount uint) (description (string-ascii 100)))
  (let ((new-escrow-id (+ (var-get last-escrow-id) u1)))
    (map-set escrows
      { escrow-id: new-escrow-id }
      {
        seller: tx-sender,
        buyer: buyer,
        amount: amount,
        description: description,
        state: STATE-CREATED
      }
    )
    (var-set last-escrow-id new-escrow-id)
    (ok new-escrow-id)
  )
)

;; Get escrow details
(define-read-only (get-escrow (escrow-id uint))
  (map-get? escrows { escrow-id: escrow-id })
)
