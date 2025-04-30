;; TradeSecure: IoT Oracle Contract - Initial Setup
;; Commit Message: Add basic error codes and verification status constants

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-REGISTERED (err u101))
(define-constant ERR-DEVICE-NOT-FOUND (err u102))
(define-constant ERR-PACKAGE-NOT-FOUND (err u103))
(define-constant ERR-NOT-ACTIVE (err u104))
(define-constant ERR-INVALID-DATA (err u105))
(define-constant ERR-VERIFICATION-FAILED (err u106))
(define-constant ERR-ALREADY-VERIFIED (err u107))
(define-constant ERR-ESCROW-CALL-FAILED (err u108))

;; Verification status
(define-constant STATUS-PENDING u0)
(define-constant STATUS-IN-TRANSIT u1)
(define-constant STATUS-DELIVERED u2)
(define-constant STATUS-FAILED u3)

;; Verification thresholds
(define-constant MIN-GPS-ACCURACY u10)        ;; GPS accuracy in meters
(define-constant TIMESTAMP-THRESHOLD u600)    ;; 10 minutes (in seconds)
(define-constant DELIVERY-RADIUS u100)        ;; 100 meters

;; Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var escrow-contract principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.escrow-contract)
(define-data-var last-verification-id uint u0)