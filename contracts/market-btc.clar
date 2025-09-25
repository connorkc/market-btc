;; Title: MarketBTC - Bitcoin-Native Decentralized Marketplace
;;
;; Summary:
;; A fully decentralized marketplace built on Stacks with seamless Bitcoin settlement,
;; supporting direct sales, auctions, brand verification, and customer reviews.
;;
;; Description:
;; This contract enables a trustless commerce ecosystem where merchants can register brands,
;; list products for direct sale or auction, and build reputation through customer reviews.
;; All transactions settle with Bitcoin's security through the Stacks protocol, with
;; transparent platform fees and automated escrow functionality for auctions.

;; Constants 
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-brand-owner (err u101))
(define-constant err-invalid-price (err u102))
(define-constant err-listing-not-found (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-auction-ended (err u105))
(define-constant err-bid-too-low (err u106))
(define-constant err-no-active-auction (err u107))
(define-constant err-invalid-duration (err u108))
(define-constant err-invalid-rating (err u109))
(define-constant err-invalid-input (err u110))

;; Data Variables
(define-data-var platform-fee uint u25) ;; 2.5% fee

;; Data Maps
(define-map Brands principal 
  {
    name: (string-ascii 50),
    verified: bool,
    created-at: uint
  }
)

(define-map Products uint 
  {
    brand: principal,
    name: (string-ascii 100),
    description: (string-ascii 500),
    price: uint,
    available: bool,
    created-at: uint,
    is-auction: bool
  }
)

(define-map Auctions uint
  {
    end-block: uint,
    min-price: uint,
    highest-bid: uint,
    highest-bidder: (optional principal),
    is-active: bool
  }
)

(define-map Reviews {product-id: uint, reviewer: principal}
  {
    rating: uint,
    comment: (string-ascii 200),
    timestamp: uint
  }
)

;; Product ID counter
(define-data-var product-counter uint u0)

;; Input Validation Functions

;; Validate string is not empty and doesn't contain only whitespace
(define-private (is-valid-string (input (string-ascii 500)))
  (let ((trimmed (unwrap-panic (as-max-len? input u500))))
    (and 
      (> (len trimmed) u0)
      (not (is-eq trimmed ""))
      ;; Check it's not just whitespace (basic check for space character)
      (not (is-eq (element-at trimmed u0) (some " ")))
    )
  )
)

;; Validate brand name
(define-private (is-valid-brand-name (name (string-ascii 50)))
  (let ((trimmed-name (unwrap-panic (as-max-len? name u50))))
    (and 
      (> (len trimmed-name) u2)  ;; At least 3 characters
      (< (len trimmed-name) u51) ;; Max 50 characters
      (is-valid-string (unwrap-panic (as-max-len? trimmed-name u500)))
    )
  )
)

;; Validate product name
(define-private (is-valid-product-name (name (string-ascii 100)))
  (let ((trimmed-name (unwrap-panic (as-max-len? name u100))))
    (and 
      (> (len trimmed-name) u2)   ;; At least 3 characters
      (< (len trimmed-name) u101) ;; Max 100 characters
      (is-valid-string (unwrap-panic (as-max-len? trimmed-name u500)))
    )
  )
)

;; Validate product description
(define-private (is-valid-description (description (string-ascii 500)))
  (let ((trimmed-desc (unwrap-panic (as-max-len? description u500))))
    (and 
      (> (len trimmed-desc) u9)   ;; At least 10 characters
      (< (len trimmed-desc) u501) ;; Max 500 characters
      (is-valid-string trimmed-desc)
    )
  )
)

;; Validate comment
(define-private (is-valid-comment (comment (string-ascii 200)))
  (let ((trimmed-comment (unwrap-panic (as-max-len? comment u200))))
    (and 
      (> (len trimmed-comment) u0)   ;; At least 1 character
      (< (len trimmed-comment) u201) ;; Max 200 characters
      (is-valid-string (unwrap-panic (as-max-len? trimmed-comment u500)))
    )
  )
)

;; Brand Management Functions

;; Register a new brand
(define-public (register-brand (name (string-ascii 50)))
  (begin
    ;; Validate input
    (asserts! (is-valid-brand-name name) (err err-invalid-input))
    
    (let
      ((brand-data {
        name: name,
        verified: false,
        created-at: stacks-block-height
      }))
      (ok (map-set Brands tx-sender brand-data))
    )
  )
)

;; Verify a brand (owner only)
(define-public (verify-brand (brand-address principal))
  (if (is-eq tx-sender contract-owner)
    (let
      ((brand-data (unwrap! (map-get? Brands brand-address) 
                   (err err-not-brand-owner))))
      (ok (map-set Brands brand-address 
        (merge brand-data {verified: true}))))
    (err err-owner-only))
)

;; Direct Sale Functions

;; List a new product
(define-public (list-product 
    (product-name (string-ascii 100))
    (product-description (string-ascii 500))
    (product-price uint)
  )
  (let
    ((brand (unwrap! (map-get? Brands tx-sender) (err err-not-brand-owner)))
     (product-id (+ (var-get product-counter) u1)))
    
    ;; Validate inputs
    (asserts! (is-valid-product-name product-name) (err err-invalid-input))
    (asserts! (is-valid-description product-description) (err err-invalid-input))
    (asserts! (> product-price u0) (err err-invalid-price))
    
    (begin
      (var-set product-counter product-id)
      (ok (map-set Products product-id {
        brand: tx-sender,
        name: product-name,
        description: product-description,
        price: product-price,
        available: true,
        created-at: stacks-block-height,
        is-auction: false
      }))
    )
  )
)

;; Purchase a product
(define-public (purchase-product (product-id uint))
  (let
    ((product (unwrap! (map-get? Products product-id) (err err-listing-not-found)))
     (price (get price product))
     (brand (get brand product))
     (fee (/ (* price (var-get platform-fee)) u1000)))
    
    (asserts! (get available product) (err err-listing-not-found))
    (asserts! (not (get is-auction product)) (err err-no-active-auction))
    (asserts! (>= (stx-get-balance tx-sender) price) (err err-insufficient-funds))
    
    ;; Transfer platform fee
    (unwrap! (stx-transfer? fee tx-sender contract-owner) (err err-insufficient-funds))
    ;; Transfer payment to brand
    (unwrap! (stx-transfer? (- price fee) tx-sender brand) (err err-insufficient-funds))
    ;; Update product availability
    (map-set Products product-id 
      (merge product {available: false}))
    (ok true)
  )
)

;; Auction Functions

;; Create auction for a product
(define-public (create-auction
    (auction-name (string-ascii 100))
    (auction-description (string-ascii 500))
    (auction-min-price uint)
    (auction-duration uint)
  )
  (let
    ((brand (unwrap! (map-get? Brands tx-sender) (err err-not-brand-owner)))
     (product-id (+ (var-get product-counter) u1))
     (end-block (+ stacks-block-height auction-duration)))
    
    ;; Validate inputs
    (asserts! (is-valid-product-name auction-name) (err err-invalid-input))
    (asserts! (is-valid-description auction-description) (err err-invalid-input))
    (asserts! (>= auction-duration u10) (err err-invalid-duration))
    (asserts! (> auction-min-price u0) (err err-invalid-price))

    (begin
      (var-set product-counter product-id)
      (map-set Products product-id {
        brand: tx-sender,
        name: auction-name,
        description: auction-description,
        price: auction-min-price,
        available: true,
        created-at: stacks-block-height,
        is-auction: true
      })
      (map-set Auctions product-id {
        end-block: end-block,
        min-price: auction-min-price,
        highest-bid: u0,
        highest-bidder: none,
        is-active: true
      })
      (ok true))
  )
)

;; Place bid on auction
(define-public (place-bid (product-id uint) (bid-amount uint))
  (let
    ((product (unwrap! (map-get? Products product-id) (err err-listing-not-found)))
     (auction (unwrap! (map-get? Auctions product-id) (err err-no-active-auction))))
    
    (asserts! (get is-active auction) (err err-auction-ended))
    (asserts! (<= stacks-block-height (get end-block auction)) (err err-auction-ended))
    (asserts! (>= bid-amount (get min-price auction)) (err err-bid-too-low))
    (asserts! (> bid-amount (get highest-bid auction)) (err err-bid-too-low))
    (asserts! (>= (stx-get-balance tx-sender) bid-amount) (err err-insufficient-funds))
    
    ;; Return funds to previous bidder if exists
    (match (get highest-bidder auction)
      prev-bidder (unwrap! (stx-transfer? (get highest-bid auction) contract-owner prev-bidder) (err err-insufficient-funds))
      true)
    
    ;; Accept new bid
    (unwrap! (stx-transfer? bid-amount tx-sender contract-owner) (err err-insufficient-funds))
    
    ;; Update auction
    (ok (map-set Auctions product-id
      (merge auction {
        highest-bid: bid-amount,
        highest-bidder: (some tx-sender)
      })))
  )
)

;; End auction
(define-public (end-auction (product-id uint))
  (let
    ((product (unwrap! (map-get? Products product-id) (err err-listing-not-found)))
     (auction (unwrap! (map-get? Auctions product-id) (err err-no-active-auction)))
     (brand (get brand product)))
    
    (asserts! (get is-active auction) (err err-auction-ended))
    (asserts! (>= stacks-block-height (get end-block auction)) (err err-auction-ended))
    
    (match (get highest-bidder auction)
      winner (let ((bid-amount (get highest-bid auction))
                   (fee (/ (* bid-amount (var-get platform-fee)) u1000)))
        ;; Transfer platform fee
        (unwrap! (stx-transfer? fee contract-owner contract-owner) (err err-insufficient-funds))
        ;; Transfer payment to brand
        (unwrap! (stx-transfer? (- bid-amount fee) contract-owner brand) (err err-insufficient-funds))
        ;; Update product status
        (map-set Products product-id 
          (merge product {available: false}))
        ;; Close auction
        (ok (map-set Auctions product-id
          (merge auction {is-active: false}))))
      (err err-no-active-auction))
  )
)

;; Review System

;; Add a review
(define-public (add-review 
    (target-product-id uint)
    (review-rating uint)
    (review-comment (string-ascii 200)))
  (let
    ((product (unwrap! (map-get? Products target-product-id) 
              (err err-listing-not-found))))
    
    ;; Validate inputs
    (asserts! (<= review-rating u5) (err err-invalid-rating))
    (asserts! (> review-rating u0) (err err-invalid-rating))
    (asserts! (is-valid-comment review-comment) (err err-invalid-input))
    
    (ok (map-set Reviews 
      {product-id: target-product-id, reviewer: tx-sender}
      {
        rating: review-rating,
        comment: review-comment,
        timestamp: stacks-block-height
      }))
  )
)

;; Read-only Functions

(define-read-only (get-product (product-id uint))
  (ok (map-get? Products product-id))
)

(define-read-only (get-brand (brand principal))
  (ok (map-get? Brands brand))
)

(define-read-only (get-review (product-id uint) (reviewer principal))
  (ok (map-get? Reviews {product-id: product-id, reviewer: reviewer}))
)

(define-read-only (get-auction (product-id uint))
  (ok (map-get? Auctions product-id))
)