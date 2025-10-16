(define-non-fungible-token academic-transcript uint)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_TRANSCRIPT_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_GRADE (err u103))
(define-constant ERR_NOT_OWNER (err u104))
(define-constant ERR_INSTITUTION_NOT_VERIFIED (err u105))

(define-constant ERR_SCHOLARSHIP_NOT_FOUND (err u108))
(define-constant ERR_NOT_ELIGIBLE (err u109))
(define-constant ERR_ALREADY_APPLIED (err u110))
(define-constant ERR_INSUFFICIENT_FUNDS (err u111))

(define-data-var scholarship-counter uint u0)

(define-data-var transcript-counter uint u0)
(define-data-var current-transcript-id uint u0)

(define-constant ERR_BADGE_NOT_FOUND (err u106))
(define-constant ERR_DUPLICATE_BADGE (err u107))

(define-data-var badge-counter uint u0)

(define-map verified-institutions principal bool)
(define-map transcript-data uint {
    student: principal,
    institution: principal,
    degree-type: (string-ascii 50),
    major: (string-ascii 100),
    graduation-date: uint,
    gpa: uint,
    credits: uint,
    issued-at: uint
})

(define-map student-transcripts principal (list 50 uint))
(define-map institution-issued principal (list 100 uint))

(define-map course-records uint (list 20 {
    course-code: (string-ascii 20),
    course-name: (string-ascii 100),
    credits: uint,
    grade: (string-ascii 2),
    semester: (string-ascii 20)
}))

(define-public (add-verified-institution (institution principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (ok (map-set verified-institutions institution true))
    )
)

(define-public (remove-verified-institution (institution principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (ok (map-delete verified-institutions institution))
    )
)

(define-public (issue-transcript 
    (student principal)
    (degree-type (string-ascii 50))
    (major (string-ascii 100))
    (graduation-date uint)
    (gpa uint)
    (credits uint)
    (courses (list 20 {
        course-code: (string-ascii 20),
        course-name: (string-ascii 100),
        credits: uint,
        grade: (string-ascii 2),
        semester: (string-ascii 20)
    }))
)
    (let (
        (transcript-id (+ (var-get transcript-counter) u1))
        (current-block stacks-block-height)
    )
        (asserts! (default-to false (map-get? verified-institutions tx-sender)) ERR_INSTITUTION_NOT_VERIFIED)
        (asserts! (<= gpa u400) ERR_INVALID_GRADE)
        
        (try! (nft-mint? academic-transcript transcript-id student))
        
        (map-set transcript-data transcript-id {
            student: student,
            institution: tx-sender,
            degree-type: degree-type,
            major: major,
            graduation-date: graduation-date,
            gpa: gpa,
            credits: credits,
            issued-at: current-block
        })
        
        (map-set course-records transcript-id courses)
        
        (map-set student-transcripts student 
            (unwrap-panic (as-max-len? 
                (append (default-to (list) (map-get? student-transcripts student)) transcript-id) 
                u50
            ))
        )
        
        (map-set institution-issued tx-sender
            (unwrap-panic (as-max-len?
                (append (default-to (list) (map-get? institution-issued tx-sender)) transcript-id)
                u100
            ))
        )
        
        (var-set transcript-counter transcript-id)
        (ok transcript-id)
    )
)

(define-public (transfer-transcript (transcript-id uint) (recipient principal))
    (let (
        (transcript-owner (unwrap! (nft-get-owner? academic-transcript transcript-id) ERR_TRANSCRIPT_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender transcript-owner) ERR_NOT_OWNER)
        (try! (nft-transfer? academic-transcript transcript-id tx-sender recipient))
        
        (var-set current-transcript-id transcript-id)
        
        (let (
            (old-owner-transcripts (default-to (list) (map-get? student-transcripts tx-sender)))
            (new-owner-transcripts (default-to (list) (map-get? student-transcripts recipient)))
        )
            (map-set student-transcripts tx-sender 
                (filter remove-current-transcript old-owner-transcripts)
            )
            (map-set student-transcripts recipient
                (unwrap-panic (as-max-len?
                    (append new-owner-transcripts transcript-id)
                    u50
                ))
            )
        )
        (ok true)
    )
)

(define-private (remove-current-transcript (id uint))
    (not (is-eq id (var-get current-transcript-id)))
)

(define-read-only (get-transcript-data (transcript-id uint))
    (map-get? transcript-data transcript-id)
)

(define-read-only (get-course-records (transcript-id uint))
    (map-get? course-records transcript-id)
)

(define-read-only (get-student-transcripts (student principal))
    (map-get? student-transcripts student)
)

(define-read-only (get-institution-issued (institution principal))
    (map-get? institution-issued institution)
)

(define-read-only (get-transcript-owner (transcript-id uint))
    (nft-get-owner? academic-transcript transcript-id)
)

(define-read-only (is-verified-institution (institution principal))
    (default-to false (map-get? verified-institutions institution))
)

(define-read-only (get-total-transcripts)
    (var-get transcript-counter)
)

(define-public (verify-transcript (transcript-id uint))
    (let (
        (transcript-info (unwrap! (get-transcript-data transcript-id) ERR_TRANSCRIPT_NOT_FOUND))
        (institution (get institution transcript-info))
    )
        (ok {
            transcript-id: transcript-id,
            is-valid: (is-verified-institution institution),
            institution: institution,
            student: (get student transcript-info),
            issued-at: (get issued-at transcript-info)
        })
    )
)

(define-public (get-student-gpa-summary (student principal))
    (let (
        (transcript-ids (default-to (list) (get-student-transcripts student)))
    )
        (ok (map get-gpa-from-transcript transcript-ids))
    )
)

(define-private (get-gpa-from-transcript (transcript-id uint))
    (let (
        (transcript-info (unwrap-panic (get-transcript-data transcript-id)))
    )
        {
            transcript-id: transcript-id,
            gpa: (get gpa transcript-info),
            degree-type: (get degree-type transcript-info),
            major: (get major transcript-info)
        }
    )
)

(define-public (update-transcript-courses (transcript-id uint) (new-courses (list 20 {
    course-code: (string-ascii 20),
    course-name: (string-ascii 100),
    credits: uint,
    grade: (string-ascii 2),
    semester: (string-ascii 20)
})))
    (let (
        (transcript-info (unwrap! (get-transcript-data transcript-id) ERR_TRANSCRIPT_NOT_FOUND))
        (institution (get institution transcript-info))
    )
        (asserts! (is-eq tx-sender institution) ERR_NOT_AUTHORIZED)
        (asserts! (is-verified-institution institution) ERR_INSTITUTION_NOT_VERIFIED)
        (ok (map-set course-records transcript-id new-courses))
    )
)

(define-public (get-institution-stats (institution principal))
    (let (
        (issued-transcripts (default-to (list) (get-institution-issued institution)))
    )
        (ok {
            institution: institution,
            is-verified: (is-verified-institution institution),
            total-issued: (len issued-transcripts),
            transcript-ids: issued-transcripts
        })
    )
)

(define-public (batch-verify-transcripts (transcript-ids (list 10 uint)))
    (ok (map verify-single-transcript transcript-ids))
)

(define-private (verify-single-transcript (transcript-id uint))
    (let (
        (transcript-info (unwrap-panic (get-transcript-data transcript-id)))
        (institution (get institution transcript-info))
    )
        {
            transcript-id: transcript-id,
            is-valid: (is-verified-institution institution),
            institution: institution
        }
    )
)

(define-read-only (get-contract-info)
    {
        total-transcripts: (var-get transcript-counter),
        contract-owner: CONTRACT_OWNER
    }
)

(define-public (get-transcript-summary (transcript-id uint))
    (let (
        (transcript-info (unwrap! (get-transcript-data transcript-id) ERR_TRANSCRIPT_NOT_FOUND))
        (courses (default-to (list) (get-course-records transcript-id)))
        (owner (unwrap! (get-transcript-owner transcript-id) ERR_TRANSCRIPT_NOT_FOUND))
    )
        (ok {
            transcript-id: transcript-id,
            owner: owner,
            student: (get student transcript-info),
            institution: (get institution transcript-info),
            degree-type: (get degree-type transcript-info),
            major: (get major transcript-info),
            gpa: (get gpa transcript-info),
            credits: (get credits transcript-info),
            graduation-date: (get graduation-date transcript-info),
            course-count: (len courses),
            issued-at: (get issued-at transcript-info)
        })
    )
)

(define-map achievement-badges uint {
    transcript-id: uint,
    badge-type: (string-ascii 30),
    description: (string-ascii 100),
    issued-by: principal,
    issued-at: uint
})

(define-map student-badges principal (list 30 uint))
(define-map transcript-badges uint (list 15 uint))

(define-public (issue-achievement-badge 
    (transcript-id uint)
    (badge-type (string-ascii 30))
    (description (string-ascii 100))
)
    (let (
        (badge-id (+ (var-get badge-counter) u1))
        (transcript-info (unwrap! (get-transcript-data transcript-id) ERR_TRANSCRIPT_NOT_FOUND))
        (student (get student transcript-info))
        (current-block stacks-block-height)
    )
        (asserts! (is-eq tx-sender (get institution transcript-info)) ERR_NOT_AUTHORIZED)
        (asserts! (is-verified-institution tx-sender) ERR_INSTITUTION_NOT_VERIFIED)
        
        (map-set achievement-badges badge-id {
            transcript-id: transcript-id,
            badge-type: badge-type,
            description: description,
            issued-by: tx-sender,
            issued-at: current-block
        })
        
        (map-set student-badges student
            (unwrap-panic (as-max-len?
                (append (default-to (list) (map-get? student-badges student)) badge-id)
                u30
            ))
        )
        
        (map-set transcript-badges transcript-id
            (unwrap-panic (as-max-len?
                (append (default-to (list) (map-get? transcript-badges transcript-id)) badge-id)
                u15
            ))
        )
        
        (var-set badge-counter badge-id)
        (ok badge-id)
    )
)

(define-read-only (get-badge-details (badge-id uint))
    (map-get? achievement-badges badge-id)
)

(define-read-only (get-student-badges (student principal))
    (map-get? student-badges student)
)

(define-read-only (get-transcript-badges (transcript-id uint))
    (map-get? transcript-badges transcript-id)
)

(define-public (get-student-achievements (student principal))
    (let (
        (badge-ids (default-to (list) (get-student-badges student)))
    )
        (ok (map get-badge-info badge-ids))
    )
)

(define-private (get-badge-info (badge-id uint))
    (unwrap-panic (get-badge-details badge-id))
)

(define-map merit-scores principal {
    gpa-score: uint,
    credit-score: uint,
    badge-score: uint,
    total-score: uint,
    last-updated: uint
})

(define-map degree-weight-multipliers (string-ascii 50) uint)

(define-public (initialize-degree-weights)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (map-set degree-weight-multipliers "PhD" u150)
        (map-set degree-weight-multipliers "Master's" u125)
        (map-set degree-weight-multipliers "Bachelor's" u100)
        (map-set degree-weight-multipliers "Associate" u75)
        (ok true)
    )
)

(define-private (calculate-gpa-score (gpa uint) (degree-type (string-ascii 50)))
    (let (
        (base-score (* gpa u25))
        (weight-multiplier (default-to u100 (map-get? degree-weight-multipliers degree-type)))
    )
        (/ (* base-score weight-multiplier) u100)
    )
)

(define-private (calculate-credit-score (credits uint))
    (if (>= credits u120)
        u1000
        (if (>= credits u90)
            u750
            (if (>= credits u60)
                u500
                (if (>= credits u30)
                    u250
                    u100
                )
            )
        )
    )
)

(define-private (calculate-badge-score (badge-count uint))
    (* badge-count u200)
)

(define-public (update-merit-score (student principal))
    (let (
        (transcript-ids (default-to (list) (get-student-transcripts student)))
        (badge-ids (default-to (list) (get-student-badges student)))
        (current-block stacks-block-height)
    )
        (if (> (len transcript-ids) u0)
            (let (
                (latest-transcript-id (unwrap-panic (element-at transcript-ids (- (len transcript-ids) u1))))
                (transcript-info (unwrap-panic (get-transcript-data latest-transcript-id)))
                (gpa-score (calculate-gpa-score (get gpa transcript-info) (get degree-type transcript-info)))
                (credit-score (calculate-credit-score (get credits transcript-info)))
                (badge-score (calculate-badge-score (len badge-ids)))
                (total-score (+ gpa-score (+ credit-score badge-score)))
            )
                (ok (map-set merit-scores student {
                    gpa-score: gpa-score,
                    credit-score: credit-score,
                    badge-score: badge-score,
                    total-score: total-score,
                    last-updated: current-block
                }))
            )
            (ok false)
        )
    )
)

(define-read-only (get-merit-score (student principal))
    (map-get? merit-scores student)
)

(define-read-only (compare-merit-scores (student1 principal) (student2 principal))
    (let (
        (score1 (default-to {gpa-score: u0, credit-score: u0, badge-score: u0, total-score: u0, last-updated: u0} (get-merit-score student1)))
        (score2 (default-to {gpa-score: u0, credit-score: u0, badge-score: u0, total-score: u0, last-updated: u0} (get-merit-score student2)))
    )
        {
            student1: student1,
            student2: student2,
            student1-score: (get total-score score1),
            student2-score: (get total-score score2),
            winner: (if (> (get total-score score1) (get total-score score2)) student1 student2)
        }
    )
)


(define-map scholarships uint {
    name: (string-ascii 50),
    sponsor: principal,
    amount: uint,
    min-merit-score: uint,
    degree-requirement: (string-ascii 50),
    deadline: uint,
    awarded-to: (optional principal),
    created-at: uint
})

(define-map student-applications principal (list 20 uint))
(define-map scholarship-applicants uint (list 50 principal))

(define-public (create-scholarship 
    (name (string-ascii 50))
    (amount uint)
    (min-merit-score uint)
    (degree-requirement (string-ascii 50))
    (deadline uint)
)
    (let (
        (scholarship-id (+ (var-get scholarship-counter) u1))
        (current-block stacks-block-height)
    )
        (asserts! (is-verified-institution tx-sender) ERR_INSTITUTION_NOT_VERIFIED)
        (asserts! (> deadline current-block) ERR_INVALID_GRADE)
        
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        (map-set scholarships scholarship-id {
            name: name,
            sponsor: tx-sender,
            amount: amount,
            min-merit-score: min-merit-score,
            degree-requirement: degree-requirement,
            deadline: deadline,
            awarded-to: none,
            created-at: current-block
        })
        
        (var-set scholarship-counter scholarship-id)
        (ok scholarship-id)
    )
)

(define-public (apply-for-scholarship (scholarship-id uint))
    (let (
        (scholarship-info (unwrap! (map-get? scholarships scholarship-id) ERR_SCHOLARSHIP_NOT_FOUND))
        (student-merit (unwrap! (get-merit-score tx-sender) ERR_NOT_ELIGIBLE))
        (student-transcript-list (default-to (list) (get-student-transcripts tx-sender)))
        (current-applications (default-to (list) (map-get? student-applications tx-sender)))
    )
        (asserts! (> (get deadline scholarship-info) stacks-block-height) ERR_NOT_AUTHORIZED)
        (asserts! (is-none (get awarded-to scholarship-info)) ERR_ALREADY_EXISTS)
        (asserts! (>= (get total-score student-merit) (get min-merit-score scholarship-info)) ERR_NOT_ELIGIBLE)
        (asserts! (> (len student-transcript-list) u0) ERR_NOT_ELIGIBLE)
        (asserts! (is-none (index-of current-applications scholarship-id)) ERR_ALREADY_APPLIED)
        
        (map-set student-applications tx-sender
            (unwrap-panic (as-max-len? (append current-applications scholarship-id) u20))
        )
        
        (map-set scholarship-applicants scholarship-id
            (unwrap-panic (as-max-len?
                (append (default-to (list) (map-get? scholarship-applicants scholarship-id)) tx-sender)
                u50
            ))
        )
        
        (ok true)
    )
)

(define-public (award-scholarship (scholarship-id uint) (recipient principal))
    (let (
        (scholarship-info (unwrap! (map-get? scholarships scholarship-id) ERR_SCHOLARSHIP_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get sponsor scholarship-info)) ERR_NOT_AUTHORIZED)
        (asserts! (is-none (get awarded-to scholarship-info)) ERR_ALREADY_EXISTS)
        
        (try! (as-contract (stx-transfer? (get amount scholarship-info) tx-sender recipient)))
        
        (map-set scholarships scholarship-id (merge scholarship-info {awarded-to: (some recipient)}))
        (ok true)
    )
)

(define-read-only (get-scholarship-details (scholarship-id uint))
    (map-get? scholarships scholarship-id)
)

(define-read-only (get-active-scholarships)
    (ok (var-get scholarship-counter))
)

(define-private (is-scholarship-active (scholarship-id uint))
    (match (map-get? scholarships scholarship-id)
        scholarship-info (and 
            (is-none (get awarded-to scholarship-info))
            (> (get deadline scholarship-info) stacks-block-height)
        )
        false
    )
)

(define-read-only (get-student-applications (student principal))
    (map-get? student-applications student)
)


(define-map transcript-status uint {
    revoked: bool,
    reason: (string-ascii 100),
    updated-at: uint
})

(define-public (set-transcript-status 
    (transcript-id uint) 
    (is-revoked bool) 
    (reason (string-ascii 100))
)
    (let (
        (transcript-info (unwrap! (get-transcript-data transcript-id) ERR_TRANSCRIPT_NOT_FOUND))
        (issuing-institution (get institution transcript-info))
        (current-block stacks-block-height)
    )
        (asserts! (is-eq tx-sender issuing-institution) ERR_NOT_AUTHORIZED)
        (asserts! (is-verified-institution tx-sender) ERR_INSTITUTION_NOT_VERIFIED)
        
        (ok (map-set transcript-status transcript-id {
            revoked: is-revoked,
            reason: reason,
            updated-at: current-block
        }))
    )
)

(define-read-only (get-transcript-status (transcript-id uint))
    (map-get? transcript-status transcript-id)
)

(define-public (verify-transcript-v2 (transcript-id uint))
    (let (
        (transcript-info (unwrap! (get-transcript-data transcript-id) ERR_TRANSCRIPT_NOT_FOUND))
        (issuing-institution (get institution transcript-info))
        (status-data (default-to {revoked: false, reason: "", updated-at: u0} 
            (get-transcript-status transcript-id)))
        (institution-verified (is-verified-institution issuing-institution))
        (is-revoked (get revoked status-data))
        (is-currently-valid (and institution-verified (not is-revoked)))
    )
        (ok {
            transcript-id: transcript-id,
            is-valid: is-currently-valid,
            institution: issuing-institution,
            institution-verified: institution-verified,
            student: (get student transcript-info),
            issued-at: (get issued-at transcript-info),
            revoked: is-revoked,
            revocation-reason: (get reason status-data),
            status-updated-at: (get updated-at status-data)
        })
    )
)

(define-public (bulk-verify-transcripts-v2 (transcript-ids (list 10 uint)))
    (ok (map verify-transcript-status transcript-ids))
)

(define-private (verify-transcript-status (transcript-id uint))
    (let (
        (transcript-info (unwrap-panic (get-transcript-data transcript-id)))
        (issuing-institution (get institution transcript-info))
        (status-data (default-to {revoked: false, reason: "", updated-at: u0} 
            (get-transcript-status transcript-id)))
        (institution-verified (is-verified-institution issuing-institution))
        (is-revoked (get revoked status-data))
    )
        {
            transcript-id: transcript-id,
            is-valid: (and institution-verified (not is-revoked)),
            revoked: is-revoked
        }
    )
)