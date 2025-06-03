;; Conflict Transformation Contract
;; Transforms quantum cultural conflicts

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_INVALID_CONFLICT (err u401))
(define-constant ERR_ALREADY_RESOLVED (err u402))

;; Data structures
(define-map cultural-conflicts uint
  {
    reporter: principal,
    involved-parties: (list 5 principal),
    conflict-description: (string-ascii 500),
    resolution-status: (string-ascii 20),
    mediator: (optional principal),
    resolution-date: (optional uint),
    transformation-score: uint,
    created-at: uint
  })

(define-map mediator-credentials principal
  {
    is-certified: bool,
    specialization: (string-ascii 100),
    success-rate: uint,
    total-mediations: uint
  })

(define-map conflict-resolutions uint (string-ascii 1000))

(define-data-var next-conflict-id uint u1)

;; Public functions
(define-public (report-conflict
  (involved-parties (list 5 principal))
  (conflict-description (string-ascii 500)))
  (let ((conflict-id (var-get next-conflict-id)))
    (map-set cultural-conflicts conflict-id {
      reporter: tx-sender,
      involved-parties: involved-parties,
      conflict-description: conflict-description,
      resolution-status: "reported",
      mediator: none,
      resolution-date: none,
      transformation-score: u0,
      created-at: block-height
    })

    (var-set next-conflict-id (+ conflict-id u1))
    (ok conflict-id)))

(define-public (assign-mediator (conflict-id uint) (mediator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (get-mediator-certification mediator) ERR_UNAUTHORIZED)

    (match (map-get? cultural-conflicts conflict-id)
      conflict-data
      (begin
        (asserts! (is-eq (get resolution-status conflict-data) "reported") ERR_INVALID_CONFLICT)
        (map-set cultural-conflicts conflict-id
          (merge conflict-data {
            mediator: (some mediator),
            resolution-status: "in-mediation"
          }))
        (ok true))
      ERR_INVALID_CONFLICT)))

(define-public (resolve-conflict
  (conflict-id uint)
  (resolution-description (string-ascii 1000))
  (transformation-score uint))
  (match (map-get? cultural-conflicts conflict-id)
    conflict-data
    (begin
      (asserts! (is-some (get mediator conflict-data)) ERR_UNAUTHORIZED)
      (asserts! (is-eq tx-sender (unwrap-panic (get mediator conflict-data))) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get resolution-status conflict-data) "in-mediation") ERR_ALREADY_RESOLVED)
      (asserts! (<= transformation-score u100) ERR_INVALID_CONFLICT)

      ;; Update conflict status
      (map-set cultural-conflicts conflict-id
        (merge conflict-data {
          resolution-status: "resolved",
          resolution-date: (some block-height),
          transformation-score: transformation-score
        }))

      ;; Store resolution details
      (map-set conflict-resolutions conflict-id resolution-description)

      ;; Update mediator stats
      (match (map-get? mediator-credentials tx-sender)
        mediator-data
        (map-set mediator-credentials tx-sender
          (merge mediator-data {
            total-mediations: (+ (get total-mediations mediator-data) u1),
            success-rate: (/ (+ (* (get success-rate mediator-data) (get total-mediations mediator-data)) transformation-score)
                            (+ (get total-mediations mediator-data) u1))
          }))
        false)

      (ok true))
    ERR_INVALID_CONFLICT))

(define-public (certify-mediator
  (mediator principal)
  (specialization (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set mediator-credentials mediator {
      is-certified: true,
      specialization: specialization,
      success-rate: u0,
      total-mediations: u0
    })
    (ok true)))

;; Read-only functions
(define-read-only (get-conflict-info (conflict-id uint))
  (map-get? cultural-conflicts conflict-id))

(define-read-only (get-conflict-resolution (conflict-id uint))
  (map-get? conflict-resolutions conflict-id))

(define-read-only (get-mediator-info (mediator principal))
  (map-get? mediator-credentials mediator))

(define-read-only (get-mediator-certification (mediator principal))
  (match (map-get? mediator-credentials mediator)
    mediator-data (get is-certified mediator-data)
    false))

(define-read-only (get-next-conflict-id)
  (var-get next-conflict-id))
