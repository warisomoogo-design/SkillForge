;; Reputation & Trust Contract
;; A Clarity smart contract that implements reputation scoring, trust networks,
;; slashing mechanisms, and reputation staking for decentralized validation

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-ALREADY-EXISTS (err u201))
(define-constant ERR-DOES-NOT-EXIST (err u202))
(define-constant ERR-INVALID-SCORE (err u203))
(define-constant ERR-INSUFFICIENT-REPUTATION (err u204))
(define-constant ERR-SELF-REFERENCE (err u205))
(define-constant ERR-ALREADY-REVIEWED (err u206))
(define-constant ERR-INVALID-STAKE (err u207))
(define-constant ERR-STAKE-NOT-FOUND (err u208))
(define-constant ERR-CANNOT-SLASH-SELF (err u209))
(define-constant ERR-INVALID-PERIOD (err u210))
(define-constant ERR-INSUFFICIENT-FUNDS (err u211))

;; Constants
(define-constant MAX-REPUTATION-SCORE u1000)
(define-constant MIN-REPUTATION-SCORE u0)
(define-constant INITIAL-REPUTATION u100)
(define-constant REVIEW-WEIGHT u10)
(define-constant TRUST-DECAY-BLOCKS u1440) ;; ~10 days
(define-constant MIN-STAKE-AMOUNT u10)
(define-constant SLASH-PERCENTAGE u20) ;; 20% slash on violations

;; Role definitions
(define-constant ROLE-NONE u0)
(define-constant ROLE-USER u1)
(define-constant ROLE-VALIDATOR u2)
(define-constant ROLE-ADMIN u3)

;; Review types
(define-constant REVIEW-POSITIVE u1)
(define-constant REVIEW-NEGATIVE u2)
(define-constant REVIEW-NEUTRAL u3)

;; Data maps

;; User profiles and reputation
(define-map user-profiles
  { address: principal }
  {
    reputation-score: uint,
    total-reviews: uint,
    positive-reviews: uint,
    negative-reviews: uint,
    projects-completed: uint,
    total-staked: uint,
    total-slashed: uint,
    joined-at: uint,
    last-activity: uint,
    role: uint
  }
)

;; Project reviews
(define-map project-reviews
  { project-id: uint, reviewer: principal, reviewee: principal }
  {
    score: uint,
    review-type: uint,
    comment: (string-utf8 256),
    created-at: uint,
    weight: uint
  }
)

;; Trust relationships
(define-map trust-relationships
  { truster: principal, trustee: principal }
  {
    trust-score: uint,
    created-at: uint,
    last-updated: uint,
    interactions: uint,
    stake-amount: uint
  }
)

;; Reputation stakes
(define-map reputation-stakes
  { staker: principal, stakee: principal, stake-id: uint }
  {
    amount: uint,
    skill-category: (string-utf8 64),
    created-at: uint,
    expires-at: uint,
    active: bool,
    outcome: (optional bool) ;; true = success, false = failure, none = pending
  }
)

;; Slashing records
(define-map slashing-records
  { slashed-user: principal, slash-id: uint }
  {
    slasher: principal,
    amount: uint,
    reason: (string-utf8 256),
    created-at: uint,
    approved: bool,
    disputed: bool
  }
)

;; Skill endorsements
(define-map skill-endorsements
  { user: principal, skill: (string-utf8 64), endorser: principal }
  {
    strength: uint,
    created-at: uint,
    stake-backed: bool
  }
)

;; Contract variables
(define-data-var contract-owner principal tx-sender)
(define-data-var project-counter uint u0)
(define-data-var stake-counter uint u0)
(define-data-var slash-counter uint u0)

;; Helper functions

(define-private (is-admin (address principal))
  (or 
    (is-eq address (var-get contract-owner))
    (is-eq (get-user-role address) ROLE-ADMIN)
  )
)

(define-private (is-validator (address principal))
  (>= (get-user-role address) ROLE-VALIDATOR)
)

(define-private (get-user-role (address principal))
  (default-to ROLE-NONE (get role (map-get? user-profiles { address: address })))
)

(define-private (user-exists (address principal))
  (is-some (map-get? user-profiles { address: address }))
)

(define-private (calculate-reputation-change (review-type uint) (reviewer-reputation uint))
  (let ((base-change u5))
    (/ (* base-change reviewer-reputation) u100)
  )
)

(define-private (apply-trust-decay (trust-score uint) (last-updated uint))
  (let ((blocks-passed (- block-height last-updated)))
    (if (> blocks-passed TRUST-DECAY-BLOCKS)
      (if (> trust-score (/ blocks-passed TRUST-DECAY-BLOCKS))
        (- trust-score (/ blocks-passed TRUST-DECAY-BLOCKS))
        u0)
      trust-score
    )
  )
)

;; Public functions

;; User registration and profile management

(define-public (register-user)
  (begin
    (asserts! (not (user-exists tx-sender)) ERR-ALREADY-EXISTS)
    (map-set user-profiles
      { address: tx-sender }
      {
        reputation-score: INITIAL-REPUTATION,
        total-reviews: u0,
        positive-reviews: u0,
        negative-reviews: u0,
        projects-completed: u0,
        total-staked: u0,
        total-slashed: u0,
        joined-at: block-height,
        last-activity: block-height,
        role: ROLE-USER
      }
    )
    (ok true)
  )
)

(define-public (update-role (user principal) (new-role uint))
  (let ((profile (map-get? user-profiles { address: user })))
    (begin
      (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
      (asserts! (is-some profile) ERR-DOES-NOT-EXIST)
      (asserts! (<= new-role ROLE-ADMIN) ERR-INVALID-SCORE)
      (map-set user-profiles
        { address: user }
        (merge (unwrap-panic profile) { role: new-role })
      )
      (ok true)
    )
  )
)

;; Project review system

(define-public (submit-project-review 
  (project-id uint) 
  (reviewee principal) 
  (score uint) 
  (review-type uint) 
  (comment (string-utf8 256))
)
  (let (
    (reviewer-profile (map-get? user-profiles { address: tx-sender }))
    (reviewee-profile (map-get? user-profiles { address: reviewee }))
    (reviewer-reputation (get reputation-score (unwrap! reviewer-profile ERR-DOES-NOT-EXIST)))
    (review-weight (/ reviewer-reputation u10))
  )
    (begin
      (asserts! (not (is-eq tx-sender reviewee)) ERR-SELF-REFERENCE)
      (asserts! (is-some reviewer-profile) ERR-DOES-NOT-EXIST)
      (asserts! (is-some reviewee-profile) ERR-DOES-NOT-EXIST)
      (asserts! (and (>= score u1) (<= score u5)) ERR-INVALID-SCORE)
      (asserts! (and (>= review-type REVIEW-POSITIVE) (<= review-type REVIEW-NEUTRAL)) ERR-INVALID-SCORE)
      (asserts! (is-none (map-get? project-reviews { project-id: project-id, reviewer: tx-sender, reviewee: reviewee })) ERR-ALREADY-REVIEWED)
      
      ;; Create review record
      (map-set project-reviews
        { project-id: project-id, reviewer: tx-sender, reviewee: reviewee }
        {
          score: score,
          review-type: review-type,
          comment: comment,
          created-at: block-height,
          weight: review-weight
        }
      )
      
      ;; Update reviewee's reputation
      (try! (update-reputation-from-review reviewee review-type reviewer-reputation))
      
      ;; Update reviewer's activity
      (map-set user-profiles
        { address: tx-sender }
        (merge (unwrap-panic reviewer-profile) { last-activity: block-height })
      )
      
      (ok true)
    )
  )
)

(define-private (update-reputation-from-review (user principal) (review-type uint) (reviewer-reputation uint))
  (let (
    (profile (unwrap! (map-get? user-profiles { address: user }) ERR-DOES-NOT-EXIST))
    (current-reputation (get reputation-score profile))
    (reputation-change (calculate-reputation-change review-type reviewer-reputation))
    (new-reputation 
      (if (is-eq review-type REVIEW-POSITIVE)
        (if (< (+ current-reputation reputation-change) MAX-REPUTATION-SCORE)
          (+ current-reputation reputation-change)
          MAX-REPUTATION-SCORE)
        (if (is-eq review-type REVIEW-NEGATIVE)
          (if (> current-reputation reputation-change)
            (- current-reputation reputation-change)
            MIN-REPUTATION-SCORE)
          current-reputation))) ;; REVIEW-NEUTRAL case
    (new-total-reviews (+ (get total-reviews profile) u1))
    (new-positive-reviews 
      (if (is-eq review-type REVIEW-POSITIVE) 
        (+ (get positive-reviews profile) u1) 
        (get positive-reviews profile)))
    (new-negative-reviews 
      (if (is-eq review-type REVIEW-NEGATIVE) 
        (+ (get negative-reviews profile) u1) 
        (get negative-reviews profile)))
  )
    (begin
      (map-set user-profiles
        { address: user }
        (merge profile {
          reputation-score: new-reputation,
          total-reviews: new-total-reviews,
          positive-reviews: new-positive-reviews,
          negative-reviews: new-negative-reviews,
          last-activity: block-height
        })
      )
      (ok true)
    )
  )
)

;; Trust network functions

(define-public (establish-trust (trustee principal) (trust-score uint))
  (begin
    (asserts! (not (is-eq tx-sender trustee)) ERR-SELF-REFERENCE)
    (asserts! (user-exists tx-sender) ERR-DOES-NOT-EXIST)
    (asserts! (user-exists trustee) ERR-DOES-NOT-EXIST)
    (asserts! (and (>= trust-score u1) (<= trust-score u100)) ERR-INVALID-SCORE)
    
    (map-set trust-relationships
      { truster: tx-sender, trustee: trustee }
      {
        trust-score: trust-score,
        created-at: block-height,
        last-updated: block-height,
        interactions: u1,
        stake-amount: u0
      }
    )
    (ok true)
  )
)

(define-public (update-trust (trustee principal) (new-trust-score uint))
  (let ((relationship (map-get? trust-relationships { truster: tx-sender, trustee: trustee })))
    (begin
      (asserts! (is-some relationship) ERR-DOES-NOT-EXIST)
      (asserts! (and (>= new-trust-score u1) (<= new-trust-score u100)) ERR-INVALID-SCORE)
      
      (map-set trust-relationships
        { truster: tx-sender, trustee: trustee }
        (merge (unwrap-panic relationship) {
          trust-score: new-trust-score,
          last-updated: block-height,
          interactions: (+ (get interactions (unwrap-panic relationship)) u1)
        })
      )
      (ok true)
    )
  )
)

;; Reputation staking functions

(define-public (stake-reputation 
  (stakee principal) 
  (amount uint) 
  (skill-category (string-utf8 64)) 
  (duration-blocks uint)
)
  (let (
    (staker-profile (map-get? user-profiles { address: tx-sender }))
    (stake-id (var-get stake-counter))
    (expires-at (+ block-height duration-blocks))
  )
    (begin
      (asserts! (not (is-eq tx-sender stakee)) ERR-SELF-REFERENCE)
      (asserts! (is-some staker-profile) ERR-DOES-NOT-EXIST)
      (asserts! (user-exists stakee) ERR-DOES-NOT-EXIST)
      (asserts! (>= amount MIN-STAKE-AMOUNT) ERR-INVALID-STAKE)
      (asserts! (>= (get reputation-score (unwrap-panic staker-profile)) amount) ERR-INSUFFICIENT-REPUTATION)
      (asserts! (> duration-blocks u0) ERR-INVALID-PERIOD)
      
      ;; Transfer STX as collateral
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      
      ;; Create stake record
      (map-set reputation-stakes
        { staker: tx-sender, stakee: stakee, stake-id: stake-id }
        {
          amount: amount,
          skill-category: skill-category,
          created-at: block-height,
          expires-at: expires-at,
          active: true,
          outcome: none
        }
      )
      
      ;; Update staker's profile
      (map-set user-profiles
        { address: tx-sender }
        (merge (unwrap-panic staker-profile) {
          total-staked: (+ (get total-staked (unwrap-panic staker-profile)) amount),
          last-activity: block-height
        })
      )
      
      ;; Increment stake counter
      (var-set stake-counter (+ stake-id u1))
      
      (ok stake-id)
    )
  )
)

(define-public (resolve-stake (staker principal) (stakee principal) (stake-id uint) (success bool))
  (let (
    (stake (map-get? reputation-stakes { staker: staker, stakee: stakee, stake-id: stake-id }))
    (stake-data (unwrap! stake ERR-STAKE-NOT-FOUND))
    (amount (get amount stake-data))
  )
    (begin
      (asserts! (is-validator tx-sender) ERR-NOT-AUTHORIZED)
      (asserts! (get active stake-data) ERR-DOES-NOT-EXIST)
      (asserts! (is-none (get outcome stake-data)) ERR-ALREADY-EXISTS)
      
      ;; Update stake outcome
      (map-set reputation-stakes
        { staker: staker, stakee: stakee, stake-id: stake-id }
        (merge stake-data {
          active: false,
          outcome: (some success)
        })
      )
      
      ;; Handle stake resolution
      (if success
        ;; Success: return stake + bonus to staker, boost stakee reputation
        (begin
          (try! (as-contract (stx-transfer? amount tx-sender staker)))
          (try! (boost-reputation stakee (/ amount u10)))
        )
        ;; Failure: slash stake, penalize stakee reputation
        (begin
          (try! (slash-reputation stakee (/ amount u5)))
          ;; Keep staked amount as penalty
        )
      )
      
      (ok true)
    )
  )
)

;; Slashing mechanism

(define-public (propose-slash (user principal) (amount uint) (reason (string-utf8 256)))
  (let (
    (slash-id (var-get slash-counter))
    (user-profile (map-get? user-profiles { address: user }))
  )
    (begin
      (asserts! (is-validator tx-sender) ERR-NOT-AUTHORIZED)
      (asserts! (not (is-eq tx-sender user)) ERR-CANNOT-SLASH-SELF)
      (asserts! (is-some user-profile) ERR-DOES-NOT-EXIST)
      (asserts! (> amount u0) ERR-INVALID-STAKE)
      
      (map-set slashing-records
        { slashed-user: user, slash-id: slash-id }
        {
          slasher: tx-sender,
          amount: amount,
          reason: reason,
          created-at: block-height,
          approved: false,
          disputed: false
        }
      )
      
      (var-set slash-counter (+ slash-id u1))
      (ok slash-id)
    )
  )
)

(define-public (approve-slash (user principal) (slash-id uint))
  (let ((slash-record (map-get? slashing-records { slashed-user: user, slash-id: slash-id })))
    (begin
      (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
      (asserts! (is-some slash-record) ERR-DOES-NOT-EXIST)
      (asserts! (not (get approved (unwrap-panic slash-record))) ERR-ALREADY-EXISTS)
      
      ;; Execute slash
      (try! (slash-reputation user (get amount (unwrap-panic slash-record))))
      
      ;; Update slash record
      (map-set slashing-records
        { slashed-user: user, slash-id: slash-id }
        (merge (unwrap-panic slash-record) { approved: true })
      )
      
      (ok true)
    )
  )
)

(define-private (slash-reputation (user principal) (amount uint))
  (let ((profile (unwrap! (map-get? user-profiles { address: user }) ERR-DOES-NOT-EXIST)))
    (begin
      (map-set user-profiles
        { address: user }
        (merge profile {
          reputation-score: (if (> (get reputation-score profile) amount)
                              (- (get reputation-score profile) amount)
                              MIN-REPUTATION-SCORE),
          total-slashed: (+ (get total-slashed profile) amount),
          last-activity: block-height
        })
      )
      (ok true)
    )
  )
)

(define-private (boost-reputation (user principal) (amount uint))
  (let ((profile (unwrap! (map-get? user-profiles { address: user }) ERR-DOES-NOT-EXIST)))
    (begin
      (map-set user-profiles
        { address: user }
        (merge profile {
          reputation-score: (if (< (+ (get reputation-score profile) amount) MAX-REPUTATION-SCORE)
                              (+ (get reputation-score profile) amount)
                              MAX-REPUTATION-SCORE),
          last-activity: block-height
        })
      )
      (ok true)
    )
  )
)

;; Skill endorsement functions

(define-public (endorse-skill (user principal) (skill (string-utf8 64)) (strength uint))
  (begin
    (asserts! (not (is-eq tx-sender user)) ERR-SELF-REFERENCE)
    (asserts! (user-exists tx-sender) ERR-DOES-NOT-EXIST)
    (asserts! (user-exists user) ERR-DOES-NOT-EXIST)
    (asserts! (and (>= strength u1) (<= strength u10)) ERR-INVALID-SCORE)
    
    (map-set skill-endorsements
      { user: user, skill: skill, endorser: tx-sender }
      {
        strength: strength,
        created-at: block-height,
        stake-backed: false
      }
    )
    (ok true)
  )
)

;; Read-only functions

(define-read-only (get-user-profile (user principal))
  (map-get? user-profiles { address: user })
)

(define-read-only (get-user-reputation (user principal))
  (default-to u0 (get reputation-score (map-get? user-profiles { address: user })))
)

(define-read-only (get-trust-relationship (truster principal) (trustee principal))
  (map-get? trust-relationships { truster: truster, trustee: trustee })
)

(define-read-only (get-project-review (project-id uint) (reviewer principal) (reviewee principal))
  (map-get? project-reviews { project-id: project-id, reviewer: reviewer, reviewee: reviewee })
)

(define-read-only (get-reputation-stake (staker principal) (stakee principal) (stake-id uint))
  (map-get? reputation-stakes { staker: staker, stakee: stakee, stake-id: stake-id })
)

(define-read-only (get-slashing-record (user principal) (slash-id uint))
  (map-get? slashing-records { slashed-user: user, slash-id: slash-id })
)

(define-read-only (get-skill-endorsement (user principal) (skill (string-utf8 64)) (endorser principal))
  (map-get? skill-endorsements { user: user, skill: skill, endorser: endorser })
)

(define-read-only (calculate-trust-score (truster principal) (trustee principal))
  (match (map-get? trust-relationships { truster: truster, trustee: trustee })
    relationship (apply-trust-decay 
                   (get trust-score relationship) 
                   (get last-updated relationship))
    u0
  )
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

;; Initialize contract
(begin
  (try! (register-user))
  (map-set user-profiles
    { address: tx-sender }
    {
      reputation-score: MAX-REPUTATION-SCORE,
      total-reviews: u0,
      positive-reviews: u0,
      negative-reviews: u0,
      projects-completed: u0,
      total-staked: u0,
      total-slashed: u0,
      joined-at: block-height,
      last-activity: block-height,
      role: ROLE-ADMIN
    }
  )
)
