# Architecture

The cluster is described by two independent layers. Each one has its
own source of truth in this repository and its own tooling.

## Operating system layer (`talos/`)

`talos/cluster.yaml` declares the cluster: name, API, endpoint, Talos
and Kubernetes versions and the list of nodes. It is validated against `talos/cluster.schema.json` (`just check`)

`just build` renders one machine config per node:

1. decrypt the secrets bundle (SOPS + age) into a temporary file.
2. `talosctl gen config` with the patches from `talos/all`, `talos/controlplane/` or
`talos/worker` (by role) and `talos/local/` (git-ignored, for node-local secrets).

3. apply the per-node patches from `talos/nodes/<name>/`.
4. validate every resulting config.

Patches only contain what differs: shared settings live in `all/` or per
role, and `nodes/<name>` holds what is specific to one machine (hostname,
network, install disk).

Changes are applied one node at a time: `just diff <node>` previews against
the running configuration, `just apply <node>` applies without rebooting.

### System images

System extensions are declared in `talos/schematic.yaml`. `just schematic` registers it with
[Image Factory](https://factory.talos.dev) and writes the resulting installer image
to `talos/all/installer.yaml`; `just upgrade <node>` upgrades a node to that image.

## Kubernetes layer (`kubernetes/`)

[ArgoCD](https://argo-cd.readthedocs.io) watches `main` and manages itself. `just bootstrap`
installs it once on a new cluster and applies `kubernetes/root.yaml`, the entry point of
an app-of-apps pattern:

- `applications/` holds one ArgoCD `Application` per component. Helm charts are referenced directly with
their values inline.
- `infrastructure/` and `workloads/` hold the manifest (Kustomize) of components whose source
lives in this repository: cluster components and user-facing applications respectively.

Adding a component means adding an `Application` (and a folder when it has local manifests).
Automated sync with pruning and self-healing keeps the cluster equal to `main`.

## Exposure

Services are published only inside the tailnet. Nothing is exposed to the public internet.

## Adding nodes

Add a new node to `talos/cluster.yaml`, create its `talos/nodes/<name>/` patches and apply it.
Control plane nodes should be an odd number (three) to keep etcd quorum, and replica counts of replicated
storage should be raised accordingly. The cluster endpoint is a virtual IP shared by the control plane nodes;
`talosctl` itself always targets node addresses, never the virtual IP.
