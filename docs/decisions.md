# Decisions

Short records of the choices that shape this repository. Newest last.

## 1. `talosctl` and `just` instead of a wrapper tool (2026-11)

- **Context:** community tools can generate talos configs for serveral nodes,
but they are third-party projects. One of the most used (`talhelper`) was archived
while this repository was being built.
- **Decision:** use only `talosctl` and `just`, with a patch layout (`all/`, role,
`nodes/<names>/`) that other tools can also consume.
- **Consequences:** a small amount of shell in the `justfile`; no
dependency that can disappear.

## 2. Declarative node list validated by a schema (2026-11)

- **Context:** a hand-parsed text file fails silently on typos.
- **Decision:** `talos/cluster.yaml` validated with JSON schema, read through `yq`.
- **Consequences:** errors surfaces at `just check` and in the pre-commit hook.

## 3. ArgoCD for GitOps (2026-11)

- **Context:** Flux and ArgoCD are both CNCF graduated projects.
- **Decision:** ArgoCD for its web UI, RBAC and multi-source features. Secrets are
populated inside the cluster (never stored in the repository).
- **Consequences:** heavier footprint than flux and a single, well known UI.

## 4. No secrets in the repository (2026-11)

- **Context:** the repository is public.
- **Decision:** the Talos secrets bundle is SOPS-encrypted and kept out of git; Kubernetes Secrets
are created out of band or by a secret store; a pre-commit hook and GitHub secret scanning guard against
accidents.
- **Consequences:** rebuilding the cluster needs the age key and the bundle from a separate backup (see [disaster recovery](disaster-recovery.md)).

## 5. Replicated block storage on the system disk (2026-11)

- **Context:** workloads should follow the cluster, not a node; one disk per node.
- **Decision:** Longhorn on a Talos `directory` user volume, one replica while there is one node.
- **Consequences:** data shares the disk with the system, so free-space reserve matter; replication is not a backup.

## 6. System extensions through an Image Factory schematic (2026-11)

- **Context:** since Talos 1.14, extensions belong to the install image.
- **Decision:** keep the recipe in `talos/schematic.yaml` and derive the installer image with `just schematic`.
- **Consequences:** depends on the Image Factory service; the schematic file allows rebuilding the image elsewhere.
