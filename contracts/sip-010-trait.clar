;; SIP-010 Fungible Token Standard
;; This trait defines the standard interface for fungible tokens on Stacks.

(define-trait sip-010-trait
  (
    ;; Transfer tokens to a specified principal
    ;; @param amount: the token amount to transfer
    ;; @param sender: the principal sending the tokens
    ;; @param recipient: the principal receiving the tokens
    ;; @param memo: an optional memo for the transfer
    ;; @returns: Response indicating success or failure with an error code
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))

    ;; Get the token balance for a specified principal
    ;; @param who: the principal to check balance for
    ;; @returns: Response with the token balance or an error code
    (get-balance (principal) (response uint uint))

    ;; Get the total supply of the token
    ;; @returns: Response with the total supply or an error code
    (get-total-supply () (response uint uint))

    ;; Get the token name
    ;; @returns: Response with the token name or an error code
    (get-name () (response (string-ascii 32) uint))

    ;; Get the token symbol
    ;; @returns: Response with the token symbol or an error code
    (get-symbol () (response (string-ascii 32) uint))

    ;; Get the number of decimals used by the token
    ;; @returns: Response with the number of decimals or an error code
    (get-decimals () (response uint uint))

    ;; Get the URI for the token metadata
    ;; @returns: Response with the URI or an error code
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)
