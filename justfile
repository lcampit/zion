set shell := ["bash", "-euo", "pipefail", "-c"]

cfg := "talos/cluster.yaml"
out := "talos/_out"

default:
  @just --list

# validate talos/cluster.yaml, checks for duplicates node names
check:
  check-jsonschema --schemafile talos/cluster.schema.json {{cfg}}
  @test "$(yq '.nodes | length' {{cfg}})" = "$(yq '[.nodes[].name] | unique | length' {{cfg}})" \
    || { echo "duplicate node names"; exit 1;}

# generate per node config
build: check 
  #!/usr/bin/env bash 
  set -euo pipefail 
  shopt -s nullglob
  cluster=$(yq .name {{cfg}})
  endpoint=$(yq .endpoint {{cfg}})
  talos_ver=$(yq .talosVersion {{cfg}})
  k8s_ver=$(yq .kubernetesVersion {{cfg}})
  mkdir -p {{out}} && rm -f {{out}}/*.yaml {{out}}/talosconfig
  secrets=$(mktemp) && trap 'shred -u "$secrets"' EXIT 
  sops decrypt talos/secrets.sops.yaml > "$secrets"
  args=()
  for f in talos/all/*.yaml; do args+=(--config-patch "@$f"); done 
  for f in talos/local/*.yaml; do args+=(--config-patch "@$f"); done 
  for f in talos/controlplane/*.yaml; do args+=(--config-patch-control-plane "@$f"); done 
  for f in talos/worker/*.yaml; do args+=(--config-patch-worker "@$f"); done 
  talosctl gen config "$cluster" "$endpoint" \
    --with-secrets "$secrets" \
    --talos-version "$talos_ver" --kubernetes-version "$k8s_ver" \
    --output-types controlplane,worker,talosconfig \
    --output {{out}} --force "${args[@]}"
  talosctl --talosconfig {{out}}/talosconfig config endpoints \
    $(yq '.nodes[] | select(.role == "controlplane") .ip' {{cfg}})
  yq '.nodes[] | .name + " " + .ip + " " + .role' {{cfg}} | while read -r name ip role; do 
    node_args=()
    for f in talos/nodes/$name/*.yaml; do node_args+=(--patch "@$f"); done 
    if (( ${#node_args[@]} )); then
      talosctl machineconfig patch {{out}}/$role.yaml "${node_args[@]}" -o {{out}}/$name.yaml
    else
      cp {{out}}/$role.yaml {{out}}/$name.yaml
    fi
    talosctl validate --mode metal -c {{out}}/$name.yaml
  done

# download cluster kubeconfig in talos/_out/kubeconfig
kubeconfig node:
  @ip=$(yq '.nodes[] | select(.name == "{{node}}") | .ip ' {{cfg}}); \
    test -n "$ip" -a "$ip" != null || { echo "unknown node encountered: {{node}}"; exit 1; }; \
    talosctl kubeconfig {{out}}/kubeconfig -n "$ip" -e "$ip" --force 

# show config diffs without applying 
diff node: build 
  @ip=$(yq '.nodes[] | select(.name == "{{node}}") | .ip ' {{cfg}}); \
    test -n "$ip" -a "$ip" != null || { echo "unknown node encountered: {{node}}"; exit 1; }; \
    talosctl apply-config --dry-run -n "$ip" -e "$ip" -f {{out}}/{{node}}.yaml

# apply to nodes, one node at a time 
apply node mode="no-reboot": build 
  @ip=$(yq '.nodes[] | select(.name == "{{node}}") | .ip ' {{cfg}}); \
    test -n "$ip" -a "$ip" != null || { echo "unknown node encountered: {{node}}"; exit 1; }; \
    talosctl apply-config --mode {{mode}} -n "$ip" -e "$ip" -f {{out}}/{{node}}.yaml

