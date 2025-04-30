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

;; Data maps for storing device and package information
(define-map devices
  { device-id: (string-ascii 64) }
  { 
    owner: principal,
    device-type: (string-ascii 20),
    registration-time: uint,
    active: bool,
    public-key: (buff 33),
    metadata: (optional (string-ascii 500))
  }
)

(define-map package-trackings
  { tracking-id: (string-ascii 100) }
  {
    escrow-id: uint,
    seller: principal,
    buyer: principal,
    device-ids: (list 10 (string-ascii 64)),
    destination: (string-ascii 256),
    destination-lat: int,
    destination-lng: int,
    creation-time: uint,
    status: uint,
    last-updated: uint,
    verification-count: uint,
    delivery-time: (optional uint),
    metadata: (optional (string-ascii 1000))
  }
)

(define-map verification-records
  { tracking-id: (string-ascii 100), verification-id: uint }
  {
    device-id: (string-ascii 64),
    timestamp: uint,
    blockchain-time: uint,
    lat: int,
    lng: int,
    accuracy: uint,
    temperature: (optional int),
    humidity: (optional uint),
    impact: (optional uint),
    metadata: (optional (string-ascii 500))
  }
)
