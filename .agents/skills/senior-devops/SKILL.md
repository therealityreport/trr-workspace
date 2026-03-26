---
name: senior-devops
description: Workspace-local canonical owner for TRR CI/CD reliability, deployment hardening, rollback readiness, observability gates, and operational safety.
---
Use this workspace-local skill for deployment, runtime hardening, release safety, and environment-risk work across TRR repos.

## When to use
1. CI/CD, release automation, infra wiring, runtime safety, or rollback behavior is changing.
2. Delivery requires deploy gates, runbook updates, or observability coverage.
3. Deployment choices need to be paired with TRR-specific operational guardrails.

## When not to use
1. Pure feature implementation with no operational impact.
2. Architecture comparison when the problem is only stack selection.
3. Broad Kubernetes or GitOps redesign unless the task explicitly requires it.

## Ownership boundary
1. This is the canonical TRR owner for release and operational readiness.
2. Pair with workspace-local owners when application code changes are required.

## Preflight
1. Identify the deployment surface and blast radius.
2. Identify release gates:
   - build
   - migrations
   - health checks
   - alarms/logs
   - rollback trigger
3. Identify environment or secret coupling.

## Execution checklist
1. Define the release path, rollback path, and first-response runbook.
2. Require artifact, config, and migration discipline before release.
3. Confirm HA/DR, cost, and security-by-design prompts where they matter for the task.
4. Verify observability readiness:
   - logs
   - metrics
   - alarms
   - actionable dashboards or query paths
5. Keep the release path concrete and do not drift into abstract platform comparison without a task-specific need.
6. Record deploy evidence and post-deploy verification in the handoff.

## Imported strengths
1. From `devops-engineer`: deploy gates, rollback/runbook expectations, and artifact/release discipline.
2. From `cloud-architect`: HA/DR, cost, and security-by-design prompts when still useful.
3. From `monitoring-expert`: observability and alerting expectations for release readiness.

## Explicit rejections
1. No generic platform-comparison defaulting.
2. No broad Kubernetes or GitOps assumptions unless the task explicitly requires them.

## Completion contract
Return:
1. `deployment_surface`
2. `release_gates`
3. `rollback_plan`
4. `observability_gaps`
5. `operational_risks`
6. `deployment_executed`
7. `target_environment`
8. `post_deploy_verification`
