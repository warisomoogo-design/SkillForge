;; SkillForge - Skill Verification Contract
;; Handles skill NFT minting, peer validation, challenges, and evidence storage

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INSUFFICIENT-STAKE (err u103))
(define-constant ERR-INVALID-SKILL-LEVEL (err u104))
(define-constant ERR-SKILL-EXPIRED (err u105))
(define-constant ERR-CHALLENGE-NOT-ACTIVE (err u106))
(define-constant ERR-ALREADY-VALIDATED (err u107))
(define-constant ERR-INSUFFICIENT-VALIDATORS (err u108))
(define-constant ERR-UNAUTHORIZED (err u109))

;; Data Variables
(define-data-var next-skill-id uint u1)
(define-data-var next-challenge-id uint u1)
(define-data-var min-stake-amount uint u1000000) ;; 1 STX in microSTX
(define-data-var min-validators-required uint u3)
(define-data-var skill-validity-period uint u8760) ;; ~1 year in blocks

;; Data Maps
;; Skill NFTs - maps skill-id to skill data
(define-map skills
  { skill-id: uint }
  {
    owner: principal,
    skill-name: (string-ascii 50),
    skill-category: (string-ascii 30),
    skill-level: uint, ;; 1-5 scale
    evidence-hash: (string-ascii 100), ;; IPFS hash
    created-at: uint,
    expires-at: uint,
    validation-count: uint,
    is-verified: bool
  }
)

;; Skill ownership tracking
(define-map user-skills
  { user: principal, skill-name: (string-ascii 50) }
  { skill-id: uint, level: uint }
)

;; Skill challenges
(define-map challenges
  { challenge-id: uint }
  {
    creator: principal,
    skill-category: (string-ascii 30),
    required-level: uint,
    description: (string-ascii 200),
    evidence-requirement: (string-ascii 100),
    reward-amount: uint,
    created-at: uint,
    expires-at: uint,
    is-active: bool
  }
)

;; Challenge submissions
(define-map challenge-submissions
  { challenge-id: uint, submitter: principal }
  {
    evidence-hash: (string-ascii 100),
    submitted-at: uint,
    validation-count: uint,
    is-approved: bool
  }
)

;; Peer validations - tracks who validated what
(define-map validations
  { skill-id: uint, validator: principal }
  {
    stake-amount: uint,
    validated-at: uint,
    is-positive: bool
  }
)

;; Validator stakes - tracks total staked by each validator
(define-map validator-stakes
  { validator: principal }
  { total-staked: uint, successful-validations: uint, failed-validations: uint }
)

;; Read-only functions

;; Get skill details
(define-read-only (get-skill (skill-id uint))
  (map-get? skills { skill-id: skill-id })
)

;; Get user's skill level for a specific skill
(define-read-only (get-user-skill-level (user principal) (skill-name (string-ascii 50)))
  (match (map-get? user-skills { user: user, skill-name: skill-name })
    skill-data (some (get level skill-data))
    none
  )
)

;; Check if skill is still valid (not expired)
(define-read-only (is-skill-valid (skill-id uint))
  (match (map-get? skills { skill-id: skill-id })
    skill-data (< block-height (get expires-at skill-data))
    false
  )
)

;; Get challenge details
(define-read-only (get-challenge (challenge-id uint))
  (map-get? challenges { challenge-id: challenge-id })
)

;; Get challenge submission
(define-read-only (get-challenge-submission (challenge-id uint) (submitter principal))
  (map-get? challenge-submissions { challenge-id: challenge-id, submitter: submitter })
)

;; Get validator stats
(define-read-only (get-validator-stats (validator principal))
  (map-get? validator-stakes { validator: validator })
)

;; Public functions

;; Create a new skill challenge
(define-public (create-skill-challenge 
  (skill-category (string-ascii 30))
  (required-level uint)
  (description (string-ascii 200))
  (evidence-requirement (string-ascii 100))
  (reward-amount uint)
  (duration-blocks uint))
  
  (let ((challenge-id (var-get next-challenge-id)))
    (asserts! (and (>= required-level u1) (<= required-level u5)) ERR-INVALID-SKILL-LEVEL)
    (asserts! (> reward-amount u0) ERR-INSUFFICIENT-STAKE)
    
    ;; Store challenge data
    (map-set challenges
      { challenge-id: challenge-id }
      {
        creator: tx-sender,
        skill-category: skill-category,
        required-level: required-level,
        description: description,
        evidence-requirement: evidence-requirement,
        reward-amount: reward-amount,
        created-at: block-height,
        expires-at: (+ block-height duration-blocks),
        is-active: true
      }
    )
    
    ;; Increment challenge ID
    (var-set next-challenge-id (+ challenge-id u1))
    
    (ok challenge-id)
  )
)

;; Submit evidence for a skill challenge
(define-public (submit-challenge-evidence 
  (challenge-id uint)
  (evidence-hash (string-ascii 100)))
  
  (let ((challenge-data (unwrap! (map-get? challenges { challenge-id: challenge-id }) ERR-NOT-FOUND)))
    (asserts! (get is-active challenge-data) ERR-CHALLENGE-NOT-ACTIVE)
    (asserts! (< block-height (get expires-at challenge-data)) ERR-CHALLENGE-NOT-ACTIVE)
    
    ;; Check if already submitted
    (asserts! (is-none (map-get? challenge-submissions { challenge-id: challenge-id, submitter: tx-sender })) ERR-ALREADY-EXISTS)
    
    ;; Store submission
    (map-set challenge-submissions
      { challenge-id: challenge-id, submitter: tx-sender }
      {
        evidence-hash: evidence-hash,
        submitted-at: block-height,
        validation-count: u0,
        is-approved: false
      }
    )
    
    (ok true)
  )
)

;; Mint a skill NFT (after successful validation)
(define-public (mint-skill-nft
  (skill-name (string-ascii 50))
  (skill-category (string-ascii 30))
  (skill-level uint)
  (evidence-hash (string-ascii 100)))
  
  (let ((skill-id (var-get next-skill-id))
        (validity-period (var-get skill-validity-period)))
    
    (asserts! (and (>= skill-level u1) (<= skill-level u5)) ERR-INVALID-SKILL-LEVEL)
    
    ;; Create skill NFT
    (map-set skills
      { skill-id: skill-id }
      {
        owner: tx-sender,
        skill-name: skill-name,
        skill-category: skill-category,
        skill-level: skill-level,
        evidence-hash: evidence-hash,
        created-at: block-height,
        expires-at: (+ block-height validity-period),
        validation-count: u0,
        is-verified: false
      }
    )
    
    ;; Update user skills mapping
    (map-set user-skills
      { user: tx-sender, skill-name: skill-name }
      { skill-id: skill-id, level: skill-level }
    )
    
    ;; Increment skill ID
    (var-set next-skill-id (+ skill-id u1))
    
    (ok skill-id)
  )
)

;; Validate a skill with stake
(define-public (validate-skill (skill-id uint) (is-positive bool))
  (let ((skill-data (unwrap! (map-get? skills { skill-id: skill-id }) ERR-NOT-FOUND))
        (stake-amount (var-get min-stake-amount))
        (validator-data (default-to { total-staked: u0, successful-validations: u0, failed-validations: u0 }
                                   (map-get? validator-stakes { validator: tx-sender }))))
    
    ;; Check if skill is still valid
    (asserts! (< block-height (get expires-at skill-data)) ERR-SKILL-EXPIRED)
    
    ;; Check if already validated by this user
    (asserts! (is-none (map-get? validations { skill-id: skill-id, validator: tx-sender })) ERR-ALREADY-VALIDATED)
    
    ;; Transfer stake amount (simplified - in real implementation would use STX transfer)
    ;; (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    ;; Record validation
    (map-set validations
      { skill-id: skill-id, validator: tx-sender }
      {
        stake-amount: stake-amount,
        validated-at: block-height,
        is-positive: is-positive
      }
    )
    
    ;; Update validator stakes
    (map-set validator-stakes
      { validator: tx-sender }
      (merge validator-data { total-staked: (+ (get total-staked validator-data) stake-amount) })
    )
    
    ;; Update skill validation count
    (map-set skills
      { skill-id: skill-id }
      (merge skill-data { validation-count: (+ (get validation-count skill-data) u1) })
    )
    
    ;; Check if skill should be verified (enough positive validations)
    (let ((updated-skill (unwrap! (map-get? skills { skill-id: skill-id }) ERR-NOT-FOUND)))
      (if (and is-positive (>= (get validation-count updated-skill) (var-get min-validators-required)))
        (map-set skills
          { skill-id: skill-id }
          (merge updated-skill { is-verified: true })
        )
        true
      )
    )
    
    (ok true)
  )
)

;; Renew skill (extend expiration)
(define-public (renew-skill (skill-id uint) (new-evidence-hash (string-ascii 100)))
  (let ((skill-data (unwrap! (map-get? skills { skill-id: skill-id }) ERR-NOT-FOUND))
        (validity-period (var-get skill-validity-period)))
    
    ;; Only skill owner can renew
    (asserts! (is-eq tx-sender (get owner skill-data)) ERR-UNAUTHORIZED)
    
    ;; Update skill with new evidence and extended expiration
    (map-set skills
      { skill-id: skill-id }
      (merge skill-data {
        evidence-hash: new-evidence-hash,
        expires-at: (+ block-height validity-period),
        validation-count: u0,
        is-verified: false
      })
    )
    
    (ok true)
  )
)

;; Admin functions

;; Update minimum stake amount (owner only)
(define-public (set-min-stake-amount (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (var-set min-stake-amount new-amount)
    (ok true)
  )
)

;; Update minimum validators required (owner only)
(define-public (set-min-validators-required (new-count uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (> new-count u0) ERR-INVALID-SKILL-LEVEL)
    (var-set min-validators-required new-count)
    (ok true)
  )
)

;; Update skill validity period (owner only)
(define-public (set-skill-validity-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (> new-period u0) ERR-INVALID-SKILL-LEVEL)
    (var-set skill-validity-period new-period)
    (ok true)
  )
)
