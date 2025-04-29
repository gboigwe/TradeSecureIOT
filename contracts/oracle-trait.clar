;; TradeSecure: Oracle Trait Definition
;; This contract defines the interface for oracles that provide verification of physical world events
;; such as package delivery, condition monitoring, and location verification.

;; Define the oracle trait
(define-trait oracle-trait
  (
    ;; Verify delivery of goods for a specific escrow
    ;; Parameters:
    ;;   escrow-id: The ID of the escrow being verified
    ;;   tracking-id: The shipping tracking ID for validation
    ;;   verification-data: Additional verification data (e.g., delivery confirmation, timestamp)
    ;; Returns: (response bool uint) - Success or error code
    (verify-delivery 
      (uint (string-ascii 100) (string-utf8 1000)) 
      (response bool uint)
    )
    
    ;; Get the verification status for a specific escrow
    ;; Parameters:
    ;;   escrow-id: The ID of the escrow to check
    ;; Returns: (response (string-ascii 20) uint) - Status or error code
    (get-verification-status 
      (uint) 
      (response (string-ascii 20) uint)
    )
    
    ;; Check if a specific location has been reached
    ;; Parameters:
    ;;   escrow-id: The ID of the escrow
    ;;   expected-location: The expected location identifier
    ;; Returns: (response bool uint) - Whether location has been reached or error code
    (check-location 
      (uint (string-ascii 100)) 
      (response bool uint)
    )
    
    ;; Submit environmental condition data
    ;; Parameters:
    ;;   escrow-id: The ID of the escrow
    ;;   condition-data: JSON string with environmental conditions (temp, humidity, etc.)
    ;; Returns: (response bool uint) - Success or error code
    (submit-condition-data 
      (uint (string-utf8 500)) 
      (response bool uint)
    )
  )
)

;; Export the trait for use in other contracts
