#!/usr/bin/env bash
# check-ontology.sh — drift gate: canonical graph vs extracted repo facts.
# Usage: check-ontology.sh [--extract-only] [--skip-render]
# Wired from check-shell.sh --audit.
set -euo pipefail

CONFIG_DIR="${SHELL_ROOT:-$HOME/.config/shell}"
GRAPH_FILE="${CONFIG_DIR}/.agents/ontology/shell-kernel.graph.yaml"
EXTRACT_SCRIPT="${CONFIG_DIR}/bin/extract-ontology-facts.sh"
RENDER_SCRIPT="${CONFIG_DIR}/bin/render-ontology-graph.sh"
EXTRACT_ONLY=false
SKIP_RENDER=false
errors=0
warnings=0

fail() { echo "ERROR: $1"; errors=$((errors + 1)); }
warn() { echo "WARN:  $1"; warnings=$((warnings + 1)); }
ok()   { echo "OK:   $1"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --extract-only)
            EXTRACT_ONLY=true
            shift
            ;;
        --skip-render)
            SKIP_RENDER=true
            shift
            ;;
        -h|--help)
            echo "Usage: check-ontology.sh [--extract-only] [--skip-render]"
            exit 0
            ;;
        *)
            echo "check-ontology: unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

if [[ ! -f "$GRAPH_FILE" ]]; then
    fail "missing graph: $GRAPH_FILE"
    exit 1
fi

if [[ ! -x "$EXTRACT_SCRIPT" ]]; then
    fail "missing extract script: $EXTRACT_SCRIPT"
    exit 1
fi

echo "=== ontology drift gate ==="

extracted_file="$("$EXTRACT_SCRIPT")"
if [[ -f "$extracted_file" ]]; then
    ok "extracted facts: ${extracted_file#$CONFIG_DIR/}"
else
    fail "extract script did not produce output file"
fi

if [[ "$EXTRACT_ONLY" == true ]]; then
    echo "=== summary: $errors error(s), $warnings warning(s) ==="
    [[ "$errors" -eq 0 ]]
    exit $?
fi

ontology_output="$(python3 - "$CONFIG_DIR" "$GRAPH_FILE" "$extracted_file" <<'PY'
import os
import re
import sys

config_dir, graph_path, extracted_path = sys.argv[1:4]
errors = []

def read_text(path: str) -> str:
    with open(path, encoding="utf-8") as handle:
        return handle.read()

graph_text = read_text(graph_path)
extracted_text = read_text(extracted_path)

meta_match = re.search(r"layout_variant:\s*(\S+)", graph_text)
graph_layout_variant = meta_match.group(1) if meta_match else ""
extracted_layout = re.search(r"layout_variant:\s*\"?(\S+)\"?", extracted_text)
extracted_layout_variant = extracted_layout.group(1).strip('"') if extracted_layout else ""
if graph_layout_variant and extracted_layout_variant and graph_layout_variant != extracted_layout_variant:
    errors.append(
        f"layout_variant drift: graph={graph_layout_variant} extracted={extracted_layout_variant}"
    )

nodes = {}
current = None
for line in graph_text.splitlines():
    if line.startswith("  - id:"):
        current = {"id": line.split(":", 1)[1].strip()}
        nodes[current["id"]] = current
    elif current is not None:
        stripped = line.strip()
        if stripped.startswith("type:"):
            current["type"] = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("name:"):
            current["name"] = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("path:"):
            current["path"] = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("file:"):
            current["file"] = stripped.split(":", 1)[1].strip()

def repo_path(relative_path: str) -> str:
    return os.path.join(config_dir, relative_path)

def exists_in_repo(relative_path: str) -> bool:
    full_path = repo_path(relative_path)
    return os.path.isfile(full_path) or os.path.isdir(full_path)

def function_in_file(relative_file: str, function_name: str) -> bool:
    full_path = repo_path(relative_file)
    if not os.path.isfile(full_path):
        return False
    text = read_text(full_path)
    return bool(re.search(rf"^{re.escape(function_name)}\s*\(\)", text, re.M))

def artifact_exists(relative_path: str) -> bool:
    if exists_in_repo(relative_path):
        return True
    if relative_path == ".path.contract" and exists_in_repo(".path.contract.example"):
        return True
    if relative_path == "local/path.contract" and exists_in_repo("local/path.contract.example"):
        return True
    return False

for node_id, node in nodes.items():
    node_type = node.get("type")
    if node_type == "Artifact" and "path" in node:
        artifact_path = node["path"]
        if not artifact_exists(artifact_path):
            errors.append(f"missing artifact {node_id}: {artifact_path}")
    if node_type == "Function" and "file" in node and "name" in node:
        if not function_in_file(node["file"], node["name"]):
            errors.append(
                f"missing function {node['name']} in {node['file']} ({node_id})"
            )
    if node_type == "Hook" and "file" in node:
        hook_file = node["file"]
        if not os.path.isfile(repo_path(hook_file)):
            errors.append(f"missing hook file {node_id}: {hook_file}")

for alias_name in ("ab", "av", "at"):
    block = re.search(
        rf"- alias: {alias_name}\n(?:    .*\n)*?    ok: (true|false)",
        extracted_text,
    )
    if block and "ok: false" in block.group(0):
        errors.append(f"alias drift: {alias_name}")

for variable_name in (
    "SHELL_VERIFICATION_ROOT",
    "SHELL_VERIFICATION_BIN",
    "SHELL_VERIFICATION_LIB",
):
    block = re.search(
        rf"- name: {variable_name}\n    found: (true|false)",
        extracted_text,
    )
    if block and block.group(1) == "false":
        errors.append(f"missing env export: {variable_name}")

required_verify_nodes = [
    "shellyxz:VerificationBridge",
    "shellyxz:Fn_verification_script_path",
    "shellyxz:Artifact_plugins_verification",
]
for node_id in required_verify_nodes:
    if node_id not in nodes:
        errors.append(f"missing verification node: {node_id}")

for message in errors:
    print(f"ONTOLOGY_ERROR: {message}")

sys.exit(1 if errors else 0)
PY
)"
ontology_exit=$?
if [[ "$ontology_exit" -ne 0 ]]; then
    while IFS= read -r ontology_error_line; do
        [[ -n "$ontology_error_line" ]] || continue
        fail "${ontology_error_line#ONTOLOGY_ERROR: }"
    done <<< "$ontology_output"
else
    ok "graph matches extracted repo facts"
fi

if [[ "$SKIP_RENDER" == false ]] && [[ -x "$RENDER_SCRIPT" ]]; then
    for subgraph_name in path boundary load_order verify; do
        if "$RENDER_SCRIPT" --subgraph "$subgraph_name" >/dev/null 2>&1; then
            ok "render-ontology-graph --subgraph $subgraph_name"
        else
            fail "render-ontology-graph --subgraph $subgraph_name"
        fi
    done
elif [[ ! -x "$RENDER_SCRIPT" ]]; then
    warn "render-ontology-graph.sh missing or not executable"
fi

echo ""
echo "=== summary: $errors error(s), $warnings warning(s) ==="
[[ "$errors" -eq 0 ]]
