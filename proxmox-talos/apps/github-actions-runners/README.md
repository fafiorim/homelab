# GitHub Actions Runners

This app deploys Actions Runner Controller (ARC) with the supported runner scale set charts. It creates:

- `arc-controller` in namespace `arc-systems`
- `homelab-arc-runners` in namespace `arc-runners`
- `upwind-demo-arc-runners` in namespace `arc-runners`

The runner scale set is registered to `https://github.com/fafiorim/homelab` and is named `homelab-arc-runners`, so workflows can use:

```yaml
runs-on: homelab-arc-runners
```

The `upwind-demo-arc-runners` scale set is registered to `https://github.com/fafiorim/upwind-demo`, so workflows in that repository can use:

```yaml
runs-on: upwind-demo-arc-runners
```

## Capacity

The initial scale policy keeps one idle runner ready and scales up to six total runners:

```yaml
minRunners: 1
maxRunners: 6
```

This gives the two-worker Talos cluster more GitHub Actions concurrency while still putting a hard cap on Docker-in-Docker pods. Tune `maxRunners` in each `*-runners-app.yaml` if the cluster has enough spare CPU and memory for more parallel jobs.

## Required Secret

Create the GitHub authentication secret in the `arc-runners` namespace before or right after the first Argo CD sync. A GitHub App is recommended for repository or organization runners:

```bash
kubectl create namespace arc-runners
kubectl label namespace arc-runners \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/warn=privileged \
  --overwrite

kubectl create secret generic arc-github-auth \
  --namespace arc-runners \
  --from-literal=github_app_id='<app-id>' \
  --from-literal=github_app_installation_id='<installation-id>' \
  --from-file=github_app_private_key=private-key.pem
```

The GitHub App needs permissions to manage self-hosted runners for the target repository or organization.

For a quick repository-level bootstrap with a classic PAT:

```bash
kubectl create secret generic arc-github-auth \
  --namespace arc-runners \
  --from-literal=github_token='<pat-with-repo-access>'
```

Do not commit the token or GitHub App private key to this repository.

## Notes

- `containerMode.type: dind` is enabled so Docker-based build workflows, including `docker/build-push-action`, can run on the self-hosted runners.
- The runner Application explicitly points at the generated controller service account, `arc-gha-rs-controller`, because Argo CD renders Helm charts without relying on the chart's live-cluster lookup.
- If the runner app syncs before the controller CRDs are ready, Argo CD may retry once the controller app has finished installing.

## References

- GitHub ARC quickstart: https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/quickstart-for-actions-runner-controller
- Runner scale sets: https://docs.github.com/en/actions/how-tos/manage-runners/use-actions-runner-controller/deploy-runner-scale-sets
- ARC charts: https://github.com/actions/actions-runner-controller
