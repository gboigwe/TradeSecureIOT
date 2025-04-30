;; TradeSecure: IoT Oracle Contract
;; This contract connects IoT devices with the escrow system to verify physical good deliveries

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

;; Verification thresholds - all as uint to ensure type consistency
(define-constant MIN-GPS-ACCURACY u10)        ;; GPS accuracy in meters
(define-constant TIMESTAMP-THRESHOLD u600)    ;; 10 minutes (in seconds)
(define-constant DELIVERY-RADIUS u100)        ;; 100 meters

;; Data maps
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

;; Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var escrow-contract principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.escrow-contract)
(define-data-var last-verification-id uint u0)

;; Private functions

;; Simple approach for distance calculation
;; This avoids complex math that's hard to type-check in Clarity
;; For close distances, a simplified approach works fine
(define-private (is-within-distance (lat1 int) (lng1 int) (lat2 int) (lng2 int) (max-distance uint))
  ;; Simple bounding box check for efficiency
  (let (
    ;; Convert lat/lng to a simpler scale for comparison
    (lat-diff-abs (if (> lat1 lat2) (- lat1 lat2) (- lat2 lat1)))
    (lng-diff-abs (if (> lng1 lng2) (- lng1 lng2) (- lng2 lng1)))
    
    ;; Very rough conversion of meters to coordinate units
    ;; This is an approximation but works well enough for short distances
    (max-distance-in-coord-units (to-int (* max-distance u9))) ;; ~0.000009 per meter
  )
    ;; If either difference exceeds our maximum, it's definitely too far
    (if (> lat-diff-abs max-distance-in-coord-units)
      false
      (if (> lng-diff-abs max-distance-in-coord-units)
        false
        ;; For distances that might be close, do a slightly better check
        ;; Using squared distance (avoids square root)
        (let (
          (squared-distance (+ (* lat-diff-abs lat-diff-abs) (* lng-diff-abs lng-diff-abs)))
          (squared-max (* max-distance-in-coord-units max-distance-in-coord-units))
        )
          (<= squared-distance squared-max)
        )
      )
    )
  )
)

;; Check if a device is registered and active
(define-private (is-device-active (device-id (string-ascii 64)))
  (match (map-get? devices { device-id: device-id })
    device (get active device)
    false
  )
)

;; Check if data is recent enough
(define-private (is-data-recent (timestamp uint))
  (let (
    (current-time (default-to u0 (get-block-info? time block-height)))
  )
    ;; Safely handle potential wraparound
    (if (> current-time timestamp)
      (<= (- current-time timestamp) TIMESTAMP-THRESHOLD)
      false
    )
  )
)

;; Notify escrow contract of delivery - simplified with direct string
(define-private (notify-escrow (escrow-id uint))
  (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.escrow-contract 
                 confirm-delivery 
                 escrow-id 
                 "{\"delivery_confirmed\":true}")
)

;; Public functions

;; Register a new IoT device
(define-public (register-device 
  (device-id (string-ascii 64))
  (device-type (string-ascii 20))
  (public-key (buff 33))
  (metadata (optional (string-ascii 500)))
)
  (let (
    (existing-device (map-get? devices { device-id: device-id }))
  )
    ;; Check if device already exists
    (asserts! (is-none existing-device) ERR-ALREADY-REGISTERED)
    
    ;; Register the device
    (map-set devices
      { device-id: device-id }
      { 
        owner: tx-sender,
        device-type: device-type,
        registration-time: block-height,
        active: true,
        public-key: public-key,
        metadata: metadata
      }
    )
    
    (ok device-id)
  )
)

;; Set device status (active/inactive)
(define-public (set-device-status (device-id (string-ascii 64)) (active bool))
  (let (
    (device (unwrap! (map-get? devices { device-id: device-id }) ERR-DEVICE-NOT-FOUND))
  )
    ;; Check if sender is owner
    (asserts! (is-eq tx-sender (get owner device)) ERR-NOT-AUTHORIZED)
    
    ;; Update device status
    (map-set devices
      { device-id: device-id }
      (merge device { active: active })
    )
    
    (ok true)
  )
)

;; Initialize package tracking for an escrow
(define-public (init-package-tracking
  (tracking-id (string-ascii 100))
  (escrow-id uint)
  (buyer principal)
  (device-ids (list 10 (string-ascii 64)))
  (destination (string-ascii 256))
  (destination-lat int)
  (destination-lng int)
)
  (let (
    (existing-tracking (map-get? package-trackings { tracking-id: tracking-id }))
  )
    ;; Check if tracking already exists
    (asserts! (is-none existing-tracking) ERR-ALREADY-REGISTERED)
    
    ;; Create the tracking record
    (map-set package-trackings
      { tracking-id: tracking-id }
      {
        escrow-id: escrow-id,
        seller: tx-sender,
        buyer: buyer,
        device-ids: device-ids,
        destination: destination,
        destination-lat: destination-lat,
        destination-lng: destination-lng,
        creation-time: block-height,
        status: STATUS-PENDING,
        last-updated: block-height,
        verification-count: u0,
        delivery-time: none,
        metadata: none
      }
    )
    
    (ok true)
  )
)

;; Submit location verification from an IoT device
;; Here's the full function with the correct fix:

(define-public (submit-location-verification
  (tracking-id (string-ascii 100))
  (device-id (string-ascii 64))
  (timestamp uint)
  (lat int)
  (lng int)
  (accuracy uint)
  (temperature (optional int))
  (humidity (optional uint))
  (impact (optional uint))
  (metadata (optional (string-ascii 500)))
)
  (let (
    (tracking (unwrap! (map-get? package-trackings { tracking-id: tracking-id }) ERR-PACKAGE-NOT-FOUND))
    (device (unwrap! (map-get? devices { device-id: device-id }) ERR-DEVICE-NOT-FOUND))
    (new-verification-id (+ (var-get last-verification-id) u1))
    (current-status (get status tracking))
    (is-authorized (or 
                     (is-eq tx-sender (get owner device))
                     (is-eq tx-sender (var-get contract-owner))))
  )
    ;; Check authorization
    (asserts! is-authorized ERR-NOT-AUTHORIZED)
    
    ;; Check device is active
    (asserts! (get active device) ERR-NOT-ACTIVE)
    
    ;; Check device is assigned to this package
    (asserts! (is-some (index-of (get device-ids tracking) device-id)) ERR-NOT-AUTHORIZED)
    
    ;; Check if timestamp is recent
    (asserts! (is-data-recent timestamp) ERR-INVALID-DATA)
    
    ;; Check if GPS accuracy is acceptable
    (asserts! (<= accuracy MIN-GPS-ACCURACY) ERR-INVALID-DATA)
    
    ;; Record the verification
    (map-set verification-records
      { tracking-id: tracking-id, verification-id: new-verification-id }
      {
        device-id: device-id,
        timestamp: timestamp,
        blockchain-time: block-height,
        lat: lat,
        lng: lng,
        accuracy: accuracy,
        temperature: temperature,
        humidity: humidity,
        impact: impact,
        metadata: metadata
      }
    )
    
    ;; Update verification counter
    (var-set last-verification-id new-verification-id)
    
    ;; Check if package is at destination
    (let (
      (is-at-dest (is-within-distance 
                   lat 
                   lng 
                   (get destination-lat tracking) 
                   (get destination-lng tracking)
                   DELIVERY-RADIUS))
      (new-status (if is-at-dest STATUS-DELIVERED (if (is-eq current-status STATUS-PENDING) STATUS-IN-TRANSIT current-status)))
      (verification-count (+ (get verification-count tracking) u1))
      (updated-tracking (merge tracking { 
        status: new-status,
        last-updated: block-height,
        verification-count: verification-count,
        delivery-time: (if is-at-dest (some block-height) (get delivery-time tracking))
      }))
    )
      ;; Update package tracking status
      (map-set package-trackings
        { tracking-id: tracking-id }
        updated-tracking
      )
      
      ;; Handle delivery notification separately
      (if (and is-at-dest (not (is-eq current-status STATUS-DELIVERED)))
        (notify-escrow (get escrow-id tracking))
        (begin
            (print { event: "no-delivery-notification-needed" })
            (ok true)
        )
      )
    )
  )
)

;; Manually mark a package as delivered (for authorized parties only)
(define-public (manual-delivery-verification 
  (tracking-id (string-ascii 100))
  (verification-notes (optional (string-ascii 500)))
)
  (let (
    (tracking (unwrap! (map-get? package-trackings { tracking-id: tracking-id }) ERR-PACKAGE-NOT-FOUND))
    (is-authorized (or 
                     (is-eq tx-sender (get seller tracking))
                     (is-eq tx-sender (var-get contract-owner))))
  )
    ;; Check authorization
    (asserts! is-authorized ERR-NOT-AUTHORIZED)
    
    ;; Check if already delivered
    (asserts! (not (is-eq (get status tracking) STATUS-DELIVERED)) ERR-ALREADY-VERIFIED)
    
    ;; Update package status
    (map-set package-trackings
      { tracking-id: tracking-id }
      (merge tracking { 
        status: STATUS-DELIVERED,
        last-updated: block-height,
        delivery-time: (some block-height),
        metadata: verification-notes
      })
    )
    
    ;; Notify escrow contract - with error handling
    (try! (notify-escrow (get escrow-id tracking)))
    
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

;; Set escrow contract address
(define-public (set-escrow-contract (contract-principal principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set escrow-contract contract-principal)
    (ok true)
  )
)

;; Read-only functions

;; Get device information
(define-read-only (get-device (device-id (string-ascii 64)))
  (map-get? devices { device-id: device-id })
)

;; Get package tracking information
(define-read-only (get-package-tracking (tracking-id (string-ascii 100)))
  (map-get? package-trackings { tracking-id: tracking-id })
)

;; Get verification record
(define-read-only (get-verification-record (tracking-id (string-ascii 100)) (verification-id uint))
  (map-get? verification-records { tracking-id: tracking-id, verification-id: verification-id })
)

;; Get contract owner
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

;; Get escrow contract
(define-read-only (get-escrow-contract)
  (var-get escrow-contract)
)

;; Get verification status as string
(define-read-only (get-verification-status-string (status uint))
  (if (is-eq status STATUS-PENDING)
    "Pending"
    (if (is-eq status STATUS-IN-TRANSIT)
      "In Transit"
      (if (is-eq status STATUS-DELIVERED)
        "Delivered"
        (if (is-eq status STATUS-FAILED)
          "Failed"
          "Unknown"
        )
      )
    )
  )
)

;; Count verifications for a package
(define-read-only (get-verification-count (tracking-id (string-ascii 100)))
  (match (map-get? package-trackings { tracking-id: tracking-id })
    tracking (get verification-count tracking)
    u0
  )
)

;; Check if a package has been delivered
(define-read-only (is-delivered (tracking-id (string-ascii 100)))
  (match (map-get? package-trackings { tracking-id: tracking-id })
    tracking (is-eq (get status tracking) STATUS-DELIVERED)
    false
  )
)
