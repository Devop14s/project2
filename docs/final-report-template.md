# Final Report Template

## 1. Team information

- Refresh `work/status-report.generated.md`, `work/service-verification.generated.md`, `work/final-report-notes.generated.md`, and `work/host-capabilities.generated.md` first with `powershell -ExecutionPolicy Bypass -File scripts\refresh-evidence.ps1 -SkipCommandChecks`.
- Use `work/final-report-notes.generated.md` as a prefilled drafting aid, then replace placeholders below with real infrastructure evidence.

- MSSV 1:
- MSSV 2:
- MSSV 3:
- MSSV 4:

## 2. Architecture summary

- cluster choice
- CI/CD tool choice
- registry choice
- deployment strategy
- first deployable service subset
- services intentionally excluded from iteration 1

## 3. Kubernetes setup

- node model
- installation steps
- screenshots
- namespace model used in the repo
- ingress or `NodePort` access pattern

## 4. CI pipeline

- webhook trigger
- build steps
- image naming and tags
- screenshots and logs
- one successful build-and-push example with tag and digest
- `work/image-digests.txt` excerpt or equivalent digest evidence
- evidence that branch builds use commit SHA or the chosen rule
- note which host or Jenkins agent actually ran the flow, using `work/host-capabilities.generated.md` or equivalent runtime-host evidence

## 5. Developer deployment flow

- job parameters
- sample branch override
- resulting endpoint
- screenshots and logs
- generated values excerpt showing overridden service tags
- rollout verification output

## 6. Cleanup flow

- cleanup job input
- deletion result
- screenshots and logs
- proof that namespace and release resources were removed
- `work/cleanup-evidence/<namespace>/<release>/` excerpt or equivalent cleanup evidence

## 7. Dev and staging flow

- dev auto deployment
- staging release deployment
- screenshots and logs
- actual image tag promoted to `dev`
- `work/commit_sha.txt` or a `work/commit-metadata.json` excerpt that includes `commit_sha` and `commit_short_sha` showing which source commit the `dev` promotion used
- actual image tag promoted to `staging`
- `work/commit_sha.txt` or a `work/commit-metadata.json` excerpt that includes `commit_sha` and `commit_short_sha` showing which source commit the `staging` release or GitOps promotion used
- excerpt from `work/runtime-evidence/<namespace>/<release>/copied-artifacts.txt` or equivalent per-run provenance bundle

## 8. Advanced section

- ArgoCD
- Service mesh
- what is scaffold-only versus what was run for real
- screenshots of application health, sync state, or mesh behavior

## 9. Problems encountered and fixes

- issue
- root cause
- resolution
- whether the issue is fully fixed or explicitly accepted as a known gap

## 10. Conclusion

- what works
- what remains risky
- what was verified locally only
- which host/tooling constraints still applied while local evidence was collected
- what was verified end to end on real infrastructure

