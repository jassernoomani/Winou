package tn.winou.domain;

public enum PhotoStatus {
    PENDING,     // stored, waiting for the worker
    PROCESSING,
    READY,       // embedded, indexed in Qdrant and matched
    NO_ANIMAL,   // no cat/dog found: the user should retake the photo
    SKIPPED,     // species "other": stored but not matched
    FAILED       // gave up after WORKER_MAX_ATTEMPTS
}
