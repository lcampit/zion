# Disaster recovery

Reuild the cluster from this repository on a fresh machine.

> Status: written from the procedure used to build the cluster; not yet exercised end to end.

## What lives outside git (keep it backed up)

| Item | Where |
| --- | --- |
| age private key (`~/.config/sops/age/keys.txt`) | password manager |
| Talos PKI (encrypted) (`talos/secrets.sops.yaml`) | password manager + offline copy |
| Kubernetes bootstrap secrets (below) | password manager |
| Longhorn volume data | not backed up yet |

## Procedure

1. **Boot Talos.** Build an ISO for the schematic ID and Talos version
in `talos/all/installer.yaml` from <https://factory.talos.dev> and
boot the machine from it.
2. **Restore the secrets and tools.**

```sh
mkdir -p ~/.config/sops/age && cp <backup>/keys.txt ~/.config/sops/age/keys.txt
cp <backup>/secrets.sops.yamla talos/secrets.sops.yaml
mise install
```

1. **Render and apply the machine config.** The first apply happens in maintenance mode,
hence `--insecure`:

```sh
just build 
talos apply-config --insecure -n <node-ip> -f talos/_out/<node>.yaml
```

1. **Bootstrap etcd, once, on on one control plane node.**

```sh
talosctl bootstrap -n <node-ip> -e <node-ip>
just health 
just kubeconfig <node>
```

1. **Hand control to ArgoCD.**

```sh
just bootstrap
```

1. **Recreate the Kubernetes secrets.** (values from the password manager). ArgoCD
creates the namespaces; the pods wait until the Secrets exists:

```sh
kubectl -n <namespace> create secret generic <secret-name> --from-literal=<key>=<value> ...
```
