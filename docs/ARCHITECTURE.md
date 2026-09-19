# CI/CD Architecture

## Pipeline Orchestrated

This document describes the final production architecture of the `pipeline-orchestrated` project.

The architecture is designed around deterministic validation, immutable artifact promotion, short-lived credentials, explicit human approval points, and recoverable production deployments.

---

## 1. Architectural Goals

The pipeline is designed to guarantee the following properties:

- application changes enter through a controlled Issue lifecycle;
- Claude Code can implement changes but cannot publish directly to Production;
- deterministic validation remains external to the agent;
- automated Pull Requests trigger CI without redundant manual approval;
- `main` remains protected by Pull Request checks;
- Release artifacts are immutable and traceable;
- Staging validates the same artifact later promoted to Production;
- Production requires explicit human approval;
- GitHub authenticates to Google Cloud without long-lived JSON credentials;
- Cloud Run uses a dedicated runtime identity;
- Production can be rolled back to a previous revision without rebuilding;
- every critical transition produces auditable evidence.

---

## 2. High-Level Architecture

```mermaid
flowchart TD
    A[GitHub Issue] --> B[claude:ready]
    B --> C[Claude Code]
    C --> D[External Maven Quality Gate]
    D --> E[GitHub App]
    E --> F[Pull Request]
    F --> G[PR Quality Gate]
    G --> H[Human Merge]
    H --> I[main]
    I --> J[Release]
    J --> K[JAR + SHA-256]
    J --> L[OCI Image]
    L --> M[GHCR image@digest]
    M --> N[Staging]
    N --> O[Smoke Test]
    O --> P[staging-promotion Manifest]
    P --> Q[Prepare Production Promotion]
    Q --> R[Human Production Approval]
    R --> S[GitHub OIDC]
    S --> T[Workload Identity Federation]
    T --> U[github-cloud-run-deployer]
    U --> V[Google Cloud Run]
    V --> W[Production HTTPS Smoke Test]
```

The central architectural rule is:

> Build once, validate once, promote the same immutable artifact.

---

## 3. Source Change Lifecycle

```mermaid
flowchart LR
    A[Issue] --> B[claude:ready]
    B --> C[claude:in-progress]
    C --> D{Agent result}
    D -->|Blocked| E[claude:blocked]
    E -->|Retry| C
    D -->|Completed| F[External verify]
    F -->|Fail| E
    F -->|Pass| G[claude:published]
    G --> H[Pull Request]
    H --> I[claude:pr-open]
    I --> J[Human Merge]
    J --> K[claude:completed]
```

### Durable Checkpoint

`claude:published` records that a valid implementation was already published.

This prevents a retry from unnecessarily rerunning Claude after a successful implementation has already reached the remote branch.

---

## 4. Responsibility Boundaries

```mermaid
flowchart TD
    A[Claude Code] -->|implements| B[Source Changes]
    C[GitHub Actions] -->|orchestrates| A
    C -->|runs| D[Deterministic Quality Gate]
    E[GitHub App] -->|publishes| F[Branch + Pull Request]
    G[Human] -->|approves merge| H[main]
    I[Release Workflow] -->|builds| J[Immutable Artifact]
    K[Staging Workflow] -->|validates| J
    L[Production Workflow] -->|promotes| J
```

### Claude Code

Responsible for:

- implementation;
- local tests allowed by project policy;
- structured task result.

Not responsible for:

- committing;
- pushing;
- creating Pull Requests;
- merging;
- deploying Production.

### GitHub Actions

Responsible for:

- lifecycle orchestration;
- deterministic validation;
- publication;
- Release;
- Staging;
- Production;
- rollback.

### Human Operators

Responsible for:

- merging approved Pull Requests;
- approving Production deployment;
- choosing rollback targets during incidents.

---

## 5. Pull Request Publication

Automated Pull Requests are published using a GitHub App installation token.

```mermaid
sequenceDiagram
    participant W as claude-issue.yml
    participant A as GitHub App
    participant G as GitHub
    participant CI as PR Quality Gate

    W->>A: Request installation token
    A-->>W: Short-lived token
    W->>G: Push branch
    W->>G: Create Pull Request
    G->>CI: Trigger pull_request
    CI-->>G: Quality Gate result
```

This avoids the redundant `Approve workflows to run` step that can occur when Pull Requests are created with `GITHUB_TOKEN`.

The human merge decision remains unchanged.

---

## 6. Deterministic Validation

The authoritative quality gate is:

```bash
./mvnw -B -ntp verify
```

The agent result is not authoritative.

```text
Claude says "completed"
        |
        v
External Maven verification
        |
        +--> PASS -> implementation accepted
        |
        +--> FAIL -> implementation rejected
```

This separation prevents the implementation agent from also becoming the final judge of its own output.

---

## 7. Release Architecture

```mermaid
flowchart TD
    A[main] --> B[Maven verify]
    B --> C[JAR]
    C --> D[JAR SHA-256]
    C --> E[Docker Build]
    E --> F[GHCR]
    F --> G[image@sha256 digest]

    A -. source identity .-> H[Git Commit SHA]
    H --> E
    D --> E
```

### Artifact Identities

| Identity | Purpose |
|---|---|
| Git commit SHA | Identifies source code |
| JAR SHA-256 | Identifies Java binary |
| OCI image digest | Identifies container image |
| Cloud Run revision | Identifies deployed runtime revision |

No `latest` tag is required for Production promotion.

---

## 8. Staging Architecture

```mermaid
flowchart TD
    A[Successful Release] --> B[Resolve image]
    B --> C[Immutable image reference]
    C --> D[Ephemeral container]
    D --> E[GET /api/v1/status]
    E -->|status = UP| F[Create staging-promotion manifest]
    E -->|failure| G[Stop promotion]
```

Staging does not rebuild the application.

It consumes the artifact produced by Release and produces durable promotion evidence.

### `staging-promotion`

The manifest records:

```text
release SHA
release run ID
staging run ID
image tag
immutable image reference
JAR SHA-256
```

Production consumes this evidence instead of rediscovering which artifact should be deployed.

---

## 9. Production Promotion

```mermaid
flowchart TD
    A[staging-promotion] --> B[Validate candidate]
    B --> C{Valid?}
    C -->|No| D[Stop]
    C -->|Yes| E[Production Environment]
    E --> F[Human Approval]
    F --> G[OIDC Authentication]
    G --> H[Workload Identity Federation]
    H --> I[Cloud Run Deployer]
    I --> J[Cloud Run Deploy]
    J --> K[Cloud Run Revision]
    K --> L[HTTPS Smoke Test]
```

The approval is placed after candidate validation.

Therefore an operator approves a known, validated artifact rather than an unverified candidate.

---

## 10. Google Cloud Identity Architecture

```mermaid
flowchart TD
    A[GitHub Actions] -->|OIDC token| B[GitHub OIDC Issuer]
    B --> C[Google Security Token Service]
    C --> D[Workload Identity Pool]
    D --> E[Workload Identity Provider]
    E --> F[github-cloud-run-deployer]
    F -->|deploy/update| G[Cloud Run]
    F -->|actAs| H[cloud-run-runtime]
    H --> I[Spring Boot Application]
```

### Deployment Identity

```text
github-cloud-run-deployer@pipeline-orchestrated-prod.iam.gserviceaccount.com
```

Used only for deployment operations.

### Runtime Identity

```text
cloud-run-runtime@pipeline-orchestrated-prod.iam.gserviceaccount.com
```

Used by the application while running.

The runtime identity must not inherit deployment administration permissions.

---

## 11. Authentication and Authorization

```text
OIDC / Workload Identity Federation
    = authentication

Google IAM roles
    = authorization

GitHub production Environment approval
    = human governance
```

These mechanisms solve different problems and must remain conceptually separated.

---

## 12. Cloud Run Runtime Model

```mermaid
flowchart TD
    A[Cloud Run Service] --> B[Stable HTTPS URL]
    A --> C[Revision N]
    A --> D[Revision N-1]
    A --> E[Revision N-2]

    C -->|100% traffic| B
    D -->|0% traffic| B
    E -->|0% traffic| B
```

A Cloud Run revision is immutable.

Production traffic can be moved between revisions without rebuilding the application.

---

## 13. External Image Import

Cloud Run may internally import an external GHCR image.

```mermaid
flowchart LR
    A[GHCR image@sha256:A] --> B[Cloud Run Import]
    B --> C[cache.us-docker.pkg.dev/...@sha256:B]
    C --> D[Cloud Run Revision]
```

The source digest and the internal runtime digest must not be assumed to be textually identical.

### Correct Validation Model

Before deployment:

```text
immutable GHCR image
OCI source revision
JAR SHA-256
```

After deployment:

```text
Cloud Run revision exists
runtime image exists
runtime digest exists
HTTPS smoke test succeeds
```

---

## 14. Production Rollback

```mermaid
flowchart TD
    A[Revision N - 100% traffic] --> B[Incident]
    B --> C[Production Rollback Workflow]
    C --> D[Validate target revision]
    D --> E[Human Production Approval]
    E --> F[Move 100% traffic]
    F --> G[Revision N-1]
    G --> H[Smoke Test]
```

Rollback is a traffic operation, not a rebuild.

The controlled rollback workflow uses:

```text
gcloud run services update-traffic
```

This preserves traceability and avoids introducing new artifacts during incident recovery.

---

## 15. Concurrency Model

Production deployment and Production rollback share the same operational target.

Only one Production-changing workflow should execute at a time.

```text
Production operation A
        |
        | active
        v
Cloud Run

Production operation B
        |
        v
WAITING
```

This prevents race conditions between simultaneous promotions or recovery operations.

---

## 16. Failure Propagation

```mermaid
flowchart TD
    A[PR Gate Failure] --> Z[STOP]
    B[Release Failure] --> Z
    C[Staging Failure] --> Z
    D[Promotion Manifest Failure] --> Z
    E[OIDC Authentication Failure] --> Z
    F[Artifact Identity Mismatch] --> Z
    G[Cloud Run Deployment Failure] --> Z
    H[Production Smoke Test Failure] --> Z
```

The architecture follows a fail-closed principle:

> An ambiguous or invalid state must stop the promotion.

---

## 17. Credential Boundaries

```mermaid
flowchart LR
    A[GITHUB_TOKEN] --> B[Issue lifecycle]
    C[GitHub App Token] --> D[Push + PR]
    E[GitHub OIDC Token] --> F[Google WIF]
    F --> G[Cloud Deploy Identity]
```

No single credential owns the entire pipeline.

This reduces blast radius and improves auditability.

---

## 18. Secrets and Variables

### Secrets

```text
CLAUDE_CODE_OAUTH_TOKEN
CLAUDE_AUTOMATION_APP_PRIVATE_KEY
```

Optional:

```text
OPENROUTER_API_KEY
```

### Variables

```text
GCP_PROJECT_ID
GCP_REGION
GCP_SERVICE_ACCOUNT
GCP_RUNTIME_SERVICE_ACCOUNT
GCP_WORKLOAD_IDENTITY_PROVIDER
GCP_CLOUD_RUN_SERVICE
CLAUDE_AUTOMATION_APP_CLIENT_ID
```

Long-lived Google Service Account JSON credentials are intentionally not used.

---

## 19. Production Evidence Chain

A Production deployment can be traced through:

```mermaid
flowchart LR
    A[Issue] --> B[Pull Request]
    B --> C[Merge Commit]
    C --> D[JAR SHA-256]
    D --> E[GHCR image@digest]
    E --> F[Staging Run]
    F --> G[Promotion Manifest]
    G --> H[Production Approval]
    H --> I[Cloud Run Revision]
    I --> J[Production Smoke Test]
```

This is the release chain of custody.

---

## 20. Canonical Production Path

There must be one canonical path for product changes:

```text
Issue
→ Claude Code
→ Quality Gate
→ GitHub App
→ Pull Request
→ PR Quality Gate
→ Human Merge
→ Release
→ Staging
→ Production Candidate
→ Human Approval
→ OIDC / WIF
→ Cloud Run
```

There must also be one canonical emergency recovery path:

```text
Production incident
→ Production Rollback
→ Human Approval
→ Cloud Run traffic reassignment
→ Smoke Test
```

Alternative deployment paths should not be kept available after validation workflows are no longer needed.

---

## 21. Architectural Principles

### Least Privilege

Every identity receives only the permissions required for its responsibility.

### Separation of Duties

Implementation, validation, publication, approval, deployment, and runtime execution are separate responsibilities.

### Immutable Promotion

Staging and Production consume the same immutable release artifact.

### Short-Lived Credentials

GitHub App installation tokens and OIDC-derived Google credentials are temporary.

### Human-in-the-Loop

Humans make high-value decisions:

```text
merge into main
deploy to Production
rollback Production
```

### Deterministic Validation

Automated agents do not decide whether their own implementation is acceptable.

### Fail Closed

Unclear states block the pipeline.

### Recoverability

Cloud Run revisions and the rollback workflow provide a controlled recovery path.

### Traceability

Every critical Production state can be related back to the source change that produced it.

---

## 22. Final Architecture

```mermaid
flowchart TD
    subgraph DEV["Change Management"]
        A[Issue]
        B[Claude Code]
        C[External Quality Gate]
        D[GitHub App]
        E[Pull Request]
        F[PR Quality Gate]
        G[Human Merge]
    end

    subgraph RELEASE["Release"]
        H[main]
        I[Maven verify]
        J[JAR + SHA-256]
        K[Docker Image]
        L[GHCR image@digest]
    end

    subgraph STAGING["Staging"]
        M[Ephemeral Runtime]
        N[Smoke Test]
        O[staging-promotion]
    end

    subgraph PROD["Production"]
        P[Candidate Validation]
        Q[Human Approval]
        R[OIDC / WIF]
        S[Cloud Run Deployer]
        T[Cloud Run Revision]
        U[Runtime Service Account]
        V[HTTPS Smoke Test]
    end

    subgraph RECOVERY["Recovery"]
        W[Production Rollback]
        X[Previous Revision]
    end

    A --> B
    B --> C
    C --> D
    D --> E
    E --> F
    F --> G
    G --> H

    H --> I
    I --> J
    J --> K
    K --> L

    L --> M
    M --> N
    N --> O

    O --> P
    P --> Q
    Q --> R
    R --> S
    S --> T
    U --> T
    T --> V

    T --> W
    W --> X
    X --> V
```

---

## 23. Core Architectural Invariant

> Production must run an artifact that was previously validated, immutably identified, explicitly approved, and operationally recoverable.

Any future architectural change should preserve this invariant unless the project deliberately replaces it with an equally strong or stronger control model.
