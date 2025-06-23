(define-non-fungible-token academic-transcript uint)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_TRANSCRIPT_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_GRADE (err u103))
(define-constant ERR_NOT_OWNER (err u104))
(define-constant ERR_INSTITUTION_NOT_VERIFIED (err u105))

(define-data-var transcript-counter uint u0)
(define-data-var current-transcript-id uint u0)

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
