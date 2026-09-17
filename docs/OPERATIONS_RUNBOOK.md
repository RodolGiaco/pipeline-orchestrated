# Operations Runbook

## Pipeline Orchestrated — Production Operations

This document defines the operational procedure for maintaining, deploying, verifying, diagnosing, and recovering the production CI/CD pipeline of the project.

The goal of this runbook is to allow an operator to manage the system without having to reconstruct the architecture from implementation history.

---

## 1. Scope

This runbook covers:

- normal pipeline execution;
- Pull Request validation;
- Release, Staging, and Production;
- manual Production approval;
- GitHub → Google Cloud authentication;
- Cloud Run service verification;
- Production rollback;
- diagnosis of common failures;
- review of identities, artifacts, and operational evidence.

This document does not contain secrets, private keys, or sensitive values.

---

## 2. Main Components

### Repository

```text
RodolGiaco/pipeline-orchestrated
```

### Google Cloud Project

```text
pipeline-orchestrated-prod
```

### Cloud Run Region

```text
southamerica-west1
```

### Cloud Run Service

```text
claude-cicd-api
```

### Container Registry

```text
ghcr.io/rodolgiaco/claude-cicd-api
```

---

## 3. Production Workflows

The canonical workflows are:

```text
.github/workflows/claude-issue.yml
.github/workflows/pr-ci.yml
.github/workflows/claude-merged.yml
.github/workflows/release.yml
.github/workflows/staging.yml
.github/workflows/production.yml
.github/workflows/production-rollback.yml
```

Temporary workflows used during infrastructure validation have been removed.

### Workflow Responsibilities

| Workflow | Responsibility |
|---|---|
| `claude-issue.yml` | Consumes approved Issues, runs Claude Code, validates changes, and publishes the branch and Pull Request |
| `pr-ci.yml` | Runs the independent Pull Request quality gate |
| `claude-merged.yml` | Finalizes the Issue lifecycle after merge |
| `release.yml` | Builds and validates the JAR, publishes the artifact, and publishes the Docker image |
| `staging.yml` | Runs ephemeral staging, smoke test, and produces `staging-promotion` |
| `production.yml` | Validates the promotion, requests human approval, and deploys to Cloud Run |
| `production-rollback.yml` | Reassigns traffic to a previous Cloud Run revision |

---

## 4. Normal Delivery Flow

```text
Issue
  |
  | claude:ready
  v
Claude Code
  |
  v
External Maven Quality Gate
  |
  v
GitHub App publishes branch + PR
  |
  v
PR Quality Gate
  |
  v
Human Merge
  |
  v
Release
  |
  +--> JAR
  +--> JAR SHA-256
  +--> Docker image
  +--> GHCR image@digest
  |
  v
Staging
  |
  +--> runtime validation
  +--> smoke test
  +--> staging-promotion manifest
  |
  v
Prepare Production Promotion
  |
  v
Human Production Approval
  |
  v
GitHub OIDC / Workload Identity Federation
  |
  v
Google Cloud Run
  |
  v
Production HTTPS Smoke Test
```

---

## 5. Human Controls

The pipeline keeps only the manual approvals that represent a meaningful decision.

### Pull Request Merge

`PR Quality Gate` is automatic.

The human decision is whether the change is accepted into `main`.

```text
PR Quality Gate ✓
        |
        v
Human Merge
```

### Production Deployment

The candidate is validated before authorization is requested.

```text
Prepare Production Promotion ✓
        |
        v
Production Environment Approval
        |
        v
Deploy Production to Cloud Run
```

There should be exactly one Production approval per promotion.

If multiple approval requests appear, check for old pending workflow runs.

---

## 6. Claude Issue Lifecycle

Labels used by the workflow:

```text
claude:ready
claude:in-progress
claude:published
claude:pr-open
claude:blocked
claude:retry
claude:completed
```

### Expected Lifecycle

```text
claude:ready
    |
    v
claude:in-progress
    |
    +--> failure --> claude:blocked
    |
    v
claude:published
    |
    v
claude:pr-open
    |
    v
merge
    |
    v
claude:completed
```

`claude:published` acts as a durable checkpoint. It indicates that a valid implementation has already been published and allows recovery without rerunning Claude unnecessarily.

---

## 7. Identities and Authentication

### GitHub App

Used for:

```text
git push
Pull Request publication
```

It should not be used as a general-purpose credential for the whole workflow.

### GITHUB_TOKEN

Used for internal GitHub responsibilities, for example:

```text
Issue labels
Issue comments
Issue lifecycle
```

### Google Cloud Deployment Identity

```text
github-cloud-run-deployer@pipeline-orchestrated-prod.iam.gserviceaccount.com
```

Responsibility:

```text
deploy/update Cloud Run
```

### Cloud Run Runtime Identity

```text
cloud-run-runtime@pipeline-orchestrated-prod.iam.gserviceaccount.com
```

Responsibility:

```text
execute the Spring Boot application
```

It must not receive deployment administration permissions.

### GitHub → Google Cloud

Production authentication uses:

```text
GitHub OIDC
        |
        v
Workload Identity Federation
        |
        v
github-cloud-run-deployer
```

Service Account JSON keys are not used.

---

## 8. Expected Variables and Secrets

### Repository Variables

Operational reference:

```text
GCP_PROJECT_ID
GCP_REGION
GCP_SERVICE_ACCOUNT
GCP_RUNTIME_SERVICE_ACCOUNT
GCP_WORKLOAD_IDENTITY_PROVIDER
GCP_CLOUD_RUN_SERVICE
CLAUDE_AUTOMATION_APP_CLIENT_ID
```

If the alternative provider is retained:

```text
USE_OPENROUTER
```

### Repository Secrets

```text
CLAUDE_CODE_OAUTH_TOKEN
CLAUDE_AUTOMATION_APP_PRIVATE_KEY
```

Optional if OpenRouter is retained:

```text
OPENROUTER_API_KEY
```

Secrets such as the following should not exist:

```text
GCP_KEY
GCP_CREDENTIALS
SERVICE_ACCOUNT_JSON
GOOGLE_APPLICATION_CREDENTIALS
```

---

## 9. Verify Production

### Resolve the Service URL

```bash
gcloud run services describe claude-cicd-api \
  --region="southamerica-west1" \
  --project="pipeline-orchestrated-prod" \
  --format="value(status.url)"
```

### Verify the Endpoint

```bash
curl -s \
  "https://<CLOUD_RUN_URL>/api/v1/status" \
  | jq
```

Minimum expected result:

```json
{
  "status": "UP"
}
```

### Verify the Active Revision

```bash
gcloud run services describe claude-cicd-api \
  --region="southamerica-west1" \
  --project="pipeline-orchestrated-prod" \
  --format="yaml(status.traffic)"
```

Expected:

```text
percent: 100
revisionName: claude-cicd-api-xxxxx-xxx
```

---

## 10. List Cloud Run Revisions

```bash
gcloud run revisions list \
  --service="claude-cicd-api" \
  --region="southamerica-west1" \
  --project="pipeline-orchestrated-prod"
```

The `ACTIVE` column indicates whether a revision is receiving traffic.

Do not assume that `latestReadyRevisionName` is always the revision currently receiving Production traffic.

For operations and rollback, inspect `status.traffic`.

---

## 11. Production Rollback

Rollback does not rebuild or redeploy the application.

Cloud Run reassigns traffic to an existing revision.

### Step 1 — List Revisions

```bash
gcloud run revisions list \
  --service="claude-cicd-api" \
  --region="southamerica-west1" \
  --project="pipeline-orchestrated-prod"
```

### Step 2 — Identify a Stable Revision

Example:

```text
Current:
claude-cicd-api-00011-bnn

Target:
claude-cicd-api-00008-vlw
```

### Step 3 — Run the Workflow

```bash
gh workflow run "Production Rollback" \
  --ref main \
  -f target_revision="claude-cicd-api-00008-vlw"
```

### Step 4 — Approve Production

In GitHub:

```text
Actions
→ Production Rollback
→ Review deployments
→ production
→ Approve and deploy
```

### Step 5 — Verify the Result

```bash
gcloud run services describe claude-cicd-api \
  --region="southamerica-west1" \
  --project="pipeline-orchestrated-prod" \
  --format="yaml(status.traffic)"
```

It must show:

```text
percent: 100
revisionName: <TARGET_REVISION>
```

### Step 6 — Smoke Test

```bash
curl -s \
  "https://<CLOUD_RUN_URL>/api/v1/status" \
  | jq
```

Confirm:

```text
status = UP
```

### Restore the Newer Revision

Use the same workflow:

```bash
gh workflow run "Production Rollback" \
  --ref main \
  -f target_revision="<CURRENT_STABLE_REVISION>"
```

Never restore Production through manual commands when the controlled workflow is available.

---

## 12. Release Diagnostics

If `release.yml` fails:

1. Review `./mvnw -B -ntp verify`.
2. Verify that exactly one publishable JAR exists.
3. Verify GitHub artifact publication.
4. Verify GHCR authentication.
5. Review the Docker build.
6. Confirm that `image@digest` was published.
7. Confirm metadata:
   - Git commit SHA
   - JAR SHA-256
   - OCI revision

Production must not continue if Release fails.

---

## 13. Staging Diagnostics

If `staging.yml` fails:

### Image Not Found

Review:

```text
release commit
image tag
GHCR package visibility
```

### Runtime Does Not Start

Review the container logs from the workflow.

### Smoke Test Fails

Validate:

```text
GET /api/v1/status
HTTP success
JSON parseable
.status == "UP"
```

### `staging-promotion` Is Not Produced

Do not continue to Production.

The manifest must only exist after Staging completes successfully.

---

## 14. Production Diagnostics

### `Prepare Production Promotion` Fails

Review:

```text
staging-promotion artifact
staging run ID
release SHA
image tag
image@digest
JAR SHA-256
```

Do not manually approve a deployment if preparation failed.

### OIDC / WIF Fails

Review:

```text
GCP_WORKLOAD_IDENTITY_PROVIDER
GCP_SERVICE_ACCOUNT
id-token: write
repository ID restrictions
repository owner ID restrictions
refs/heads/main restriction
roles/iam.workloadIdentityUser
```

Do not create a JSON key as a temporary workaround.

### `Verify promoted source image` Fails

Compare:

```text
staging-promotion.releaseSha
vs
org.opencontainers.image.revision
```

and:

```text
staging-promotion.jarSha256
vs
io.github.pipeline-orchestrated.jar.sha256
```

Any mismatch must block Production.

---

## 15. Cloud Run and Imported Digests

When Cloud Run consumes an external image from GHCR, it may import the image internally.

Therefore it is possible to observe:

```text
Source:
ghcr.io/...@sha256:A
```

and later:

```text
Runtime:
cache.us-docker.pkg.dev/...@sha256:B
```

Do not assume:

```text
A == B
```

Validation is divided into two levels.

### Before Deployment

Validate the source artifact identity:

```text
GHCR immutable image
OCI revision
JAR SHA-256
```

### After Deployment

Validate:

```text
Cloud Run revision exists
latest ready revision exists
runtime image exists
runtime digest exists
production smoke test succeeds
```

---

## 16. Cloud Run Logs

Read recent logs:

```bash
gcloud run services logs read claude-cicd-api \
  --region="southamerica-west1" \
  --project="pipeline-orchestrated-prod" \
  --limit=50
```

Filter errors:

```bash
gcloud run services logs read claude-cicd-api \
  --region="southamerica-west1" \
  --project="pipeline-orchestrated-prod" \
  --log-filter="severity>=ERROR" \
  --limit=50
```

Cloud Run automatically collects application logs written to `stdout` and `stderr`.

---

## 17. GitHub App Diagnostics

If an automated PR does not start `PR Quality Gate` automatically, review:

```text
CLAUDE_AUTOMATION_APP_CLIENT_ID
CLAUDE_AUTOMATION_APP_PRIVATE_KEY
GitHub App installation
Repository access
Contents: Read and write
Pull requests: Read and write
```

The branch push and Pull Request creation must use the GitHub App installation token, not `GITHUB_TOKEN`.

Expected behavior:

```text
Automated PR
    |
    v
PR Quality Gate starts automatically
```

There should be no intermediate manual approval required to start the quality gate.

---

## 18. Concurrency Diagnostics

Production uses a concurrency group to prevent simultaneous promotions.

If a workflow shows:

```text
Waiting for another Production workflow to complete
```

check for previous pending runs.

Do not disable the concurrency policy to solve the blockage.

If the previous run is no longer valid:

```text
Actions
→ Production
→ old run
→ Cancel workflow
```

The newer run will continue automatically.

---

## 19. Quality Gate

The authoritative project quality gate is:

```bash
./mvnw -B -ntp verify
```

Claude may run tests during implementation, but the agent result does not replace the external quality gate.

Rule:

```text
Agent says completed
        !=
Implementation accepted
```

The implementation is valid only when the deterministic gate passes.

---

## 20. Emergency Change Policy

Do not use:

```text
direct push to main
manual Production docker run
manual rebuild in Production
manual service-account JSON credentials
force push to deployment branches
```

Always prefer:

```text
Issue / controlled change
→ Pull Request
→ PR Quality Gate
→ Merge
→ Release
→ Staging
→ Production Approval
→ Cloud Run
```

For Production incidents, use:

```text
production-rollback.yml
```

---

## 21. Minimum Evidence After a Deployment

A successful deployment should allow recovery of:

```text
Issue
Pull Request
Merge commit
Release commit SHA
JAR SHA-256
GHCR image@digest
Staging run
staging-promotion manifest
Production approval
Cloud Run revision
Cloud Run runtime image
Production URL
Production smoke test
```

This information allows reconstruction of the release chain of custody.

---

## 22. System Health Criteria

The pipeline is considered operational when:

```text
PR Quality Gate                    PASS
Release                            PASS
Staging                            PASS
Production candidate validation    PASS
Production approval                RECORDED
OIDC / WIF authentication          PASS
Cloud Run deployment               PASS
Production smoke test              PASS
```

The service is considered operational when:

```text
Cloud Run traffic                  100% on intended revision
GET /api/v1/status                 HTTP 2xx
JSON status                        UP
```

---

## 23. Operational Security Rules

1. Do not store long-lived Google credentials.
2. Do not expose the GitHub App private key.
3. Do not grant cloud permissions to `cloud-run-runtime` unless explicitly required.
4. Do not modify Production through alternate routes outside the canonical workflow.
5. Do not promote a release that did not pass Staging.
6. Do not rebuild the artifact between Staging and Production.
7. Do not ignore artifact identity mismatches.
8. Do not delete revisions before determining whether they are needed for rollback.
9. Keep only one Production promotion active through concurrency.
10. Preserve human approval for Production.

---

## 24. Canonical Operational Path

```text
Development change
       |
       v
Issue
       |
       v
Claude Code
       |
       v
External Quality Gate
       |
       v
GitHub App
       |
       v
Pull Request
       |
       v
PR Quality Gate
       |
       v
Human Merge
       |
       v
Release
       |
       v
Staging
       |
       v
Promotion Manifest
       |
       v
Production Candidate Validation
       |
       v
Human Approval
       |
       v
OIDC / WIF
       |
       v
Cloud Run
       |
       v
Production Smoke Test
```

---

## 25. Core Operational Principle

> Production must execute a previously validated, identifiable, and recoverable artifact. Every critical transition must be traceable, and any ambiguous state must stop the flow.
