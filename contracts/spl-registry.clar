;; spl-registry.clar
;; SPL Content Registry and Rights Management
;; This contract enables digital content creators to register, track, and monetize their intellectual property
;; using blockchain technology, ensuring transparent and verifiable content ownership.
;; ===============================
;; Error Codes
;; ===============================
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-CONTENT-NOT-FOUND (err u101))
(define-constant ERR-CONTENT-EXISTS (err u102))
(define-constant ERR-INVALID-RIGHTS (err u103))
(define-constant ERR-TRANSFER-FAILED (err u104))
(define-constant ERR-LICENSING-ERROR (err u105))

;; ===============================
;; Data Structures
;; ===============================
;; Content registration map
(define-map content-registry
  {
    content-id: (string-ascii 36),
    creator: principal,
  }
  {
    title: (string-utf8 100),
    content-type: (string-ascii 50),
    creation-date: uint,
    description: (optional (string-utf8 500)),
    public-metadata: (optional (string-utf8 1000)),
  }
)

;; Rights and licensing map
(define-map content-rights
  {
    content-id: (string-ascii 36),
    creator: principal,
  }
  {
    base-price: uint,
    royalty-percentage: uint,
    licensing-model: (string-ascii 50),
    total-licenses-sold: uint,
    current-rights-holder: principal,
  }
)

;; Licensing transactions
(define-map license-transactions
  {
    content-id: (string-ascii 36),
    licensee: principal,
    transaction-id: (string-ascii 36),
  }
  {
    purchase-date: uint,
    license-type: (string-ascii 50),
    price-paid: uint,
    expiration: (optional uint),
  }
)

;; ===============================
;; Private Functions
;; ===============================
;; Verify content creator authorization
(define-private (is-content-creator
    (content-id (string-ascii 36))
    (creator principal)
  )
  (match (map-get? content-registry { content-id: content-id, creator: creator })
    content-info true
    false
  )
)

;; ===============================
;; Read-Only Functions
;; ===============================
;; Get content details
(define-read-only (get-content-details
    (content-id (string-ascii 36))
    (creator principal)
  )
  (match (map-get? content-registry { content-id: content-id, creator: creator })
    content-info (ok content-info)
    ERR-CONTENT-NOT-FOUND
  )
)

;; ===============================
;; Public Functions
;; ===============================
;; Register new content
(define-public (register-content
    (content-id (string-ascii 36))
    (title (string-utf8 100))
    (content-type (string-ascii 50))
    (base-price uint)
    (royalty-percentage uint)
    (licensing-model (string-ascii 50))
    (description (optional (string-utf8 500)))
    (public-metadata (optional (string-utf8 1000)))
  )
  (let ((creator tx-sender))
    ;; Ensure content doesn't already exist
    (asserts! 
      (is-none (map-get? content-registry { content-id: content-id, creator: creator }))
      ERR-CONTENT-EXISTS
    )
    ;; Validate royalty percentage
    (asserts! (<= royalty-percentage u100) ERR-INVALID-RIGHTS)
    
    ;; Register content in registry
    (map-set content-registry
      { content-id: content-id, creator: creator }
      {
        title: title,
        content-type: content-type,
        creation-date: block-height,
        description: description,
        public-metadata: public-metadata,
      }
    )
    
    ;; Set initial rights
    (map-set content-rights
      { content-id: content-id, creator: creator }
      {
        base-price: base-price,
        royalty-percentage: royalty-percentage,
        licensing-model: licensing-model,
        total-licenses-sold: u0,
        current-rights-holder: creator,
      }
    )
    
    (ok content-id)
  )
)

;; Purchase content license
(define-public (purchase-license
    (content-id (string-ascii 36))
    (creator principal)
    (license-type (string-ascii 50))
    (transaction-id (string-ascii 36))
  )
  (let ((licensee tx-sender))
    ;; Verify content exists
    (asserts! 
      (is-some (map-get? content-registry { content-id: content-id, creator: creator }))
      ERR-CONTENT-NOT-FOUND
    )
    
    ;; Retrieve content rights
    (let ((rights (unwrap! 
        (map-get? content-rights { content-id: content-id, creator: creator })
        ERR-CONTENT-NOT-FOUND
      )))
      
      ;; Record license transaction
      (map-set license-transactions
        {
          content-id: content-id,
          licensee: licensee,
          transaction-id: transaction-id,
        }
        {
          purchase-date: block-height,
          license-type: license-type,
          price-paid: (get base-price rights),
          expiration: none, ;; Placeholder for future implementation
        }
      )
      
      ;; Update total licenses sold
      (map-set content-rights
        { content-id: content-id, creator: creator }
        (merge rights { total-licenses-sold: (+ (get total-licenses-sold rights) u1) })
      )
      
      (ok transaction-id)
    )
  )
)

;; Transfer content rights
(define-public (transfer-rights
    (content-id (string-ascii 36))
    (new-rights-holder principal)
  )
  (let ((current-owner tx-sender))
    ;; Verify current ownership
    (let ((rights (unwrap! 
        (map-get? content-rights { content-id: content-id, creator: current-owner })
        ERR-CONTENT-NOT-FOUND
      )))
      
      ;; Update rights holder
      (map-set content-rights
        { content-id: content-id, creator: current-owner }
        (merge rights { current-rights-holder: new-rights-holder })
      )
      
      (ok true)
    )
  )
)