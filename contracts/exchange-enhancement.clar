;; Exchange Enhancement Contract
;; Manages quantum-enhanced cultural understanding

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_INVALID_EXCHANGE (err u201))
(define-constant ERR_INSUFFICIENT_TOKENS (err u202))

;; Data structures
(define-map cultural-exchanges uint
  {
    participant-a: principal,
    participant-b: principal,
    cultural-theme: (string-ascii 100),
    enhancement-level: uint,
    completion-status: bool,
    created-at: uint
  })

(define-map participant-tokens principal uint)
(define-map exchange-rewards uint uint)

(define-data-var next-exchange-id uint u1)

;; Public functions
(define-public (create-cultural-exchange
  (participant-b principal)
  (cultural-theme (string-ascii 100))
  (enhancement-level uint))
  (let ((exchange-id (var-get next-exchange-id)))
    (asserts! (<= enhancement-level u5) ERR_INVALID_EXCHANGE)
    (asserts! (>= (get-participant-tokens tx-sender) (* enhancement-level u10)) ERR_INSUFFICIENT_TOKENS)

    (map-set cultural-exchanges exchange-id {
      participant-a: tx-sender,
      participant-b: participant-b,
      cultural-theme: cultural-theme,
      enhancement-level: enhancement-level,
      completion-status: false,
      created-at: block-height
    })

    ;; Deduct tokens for enhancement
    (map-set participant-tokens tx-sender
      (- (get-participant-tokens tx-sender) (* enhancement-level u10)))

    (var-set next-exchange-id (+ exchange-id u1))
    (ok exchange-id)))

(define-public (complete-exchange (exchange-id uint))
  (match (map-get? cultural-exchanges exchange-id)
    exchange-data
    (begin
      (asserts! (or (is-eq tx-sender (get participant-a exchange-data))
                    (is-eq tx-sender (get participant-b exchange-data))) ERR_UNAUTHORIZED)
      (asserts! (not (get completion-status exchange-data)) ERR_INVALID_EXCHANGE)

      ;; Mark as complete
      (map-set cultural-exchanges exchange-id
        (merge exchange-data {completion-status: true}))

      ;; Reward both participants
      (let ((reward (* (get enhancement-level exchange-data) u20)))
        (map-set participant-tokens (get participant-a exchange-data)
          (+ (get-participant-tokens (get participant-a exchange-data)) reward))
        (map-set participant-tokens (get participant-b exchange-data)
          (+ (get-participant-tokens (get participant-b exchange-data)) reward)))

      (ok true))
    ERR_INVALID_EXCHANGE))

(define-public (mint-tokens (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set participant-tokens recipient
      (+ (get-participant-tokens recipient) amount))
    (ok true)))

;; Read-only functions
(define-read-only (get-exchange-info (exchange-id uint))
  (map-get? cultural-exchanges exchange-id))

(define-read-only (get-participant-tokens (participant principal))
  (default-to u0 (map-get? participant-tokens participant)))

(define-read-only (get-next-exchange-id)
  (var-get next-exchange-id))
