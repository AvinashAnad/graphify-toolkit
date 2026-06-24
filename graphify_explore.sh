#!/usr/bin/env bash
# =============================================================================
# graphify_explore.sh
# Drop this into any repo root and run it to bootstrap a knowledge graph.
# Usage: bash graphify_explore.sh [model_name]
# Example: bash graphify_explore.sh qwen3.6:35b-mlx
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Config — override via env or CLI arg
# ---------------------------------------------------------------------------
MODEL="${1:-qwen3.6:35b-mlx}"          # pass a different model as $1 if needed
OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://localhost:11434/v1}"
OLLAMA_API_KEY="${OLLAMA_API_KEY:-ollama}"
GRAPHIFY_OLLAMA_NUM_CTX="${GRAPHIFY_OLLAMA_NUM_CTX:-32768}"
GRAPHIFY_OLLAMA_KEEP_ALIVE="${GRAPHIFY_OLLAMA_KEEP_ALIVE:-0}"
TOKEN_BUDGET="${TOKEN_BUDGET:-4000}"
MAX_CONCURRENCY="${MAX_CONCURRENCY:-1}"
REPO_ROOT="$(pwd)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()    { echo "[graphify] $*"; }
success() { echo "[graphify] OK: $*"; }
warn()    { echo "[graphify] WARN: $*" >&2; }
die()     { echo "[graphify] ERROR: $*" >&2; exit 1; }

export OLLAMA_BASE_URL OLLAMA_API_KEY GRAPHIFY_OLLAMA_NUM_CTX GRAPHIFY_OLLAMA_KEEP_ALIVE

# ---------------------------------------------------------------------------
# 1. Pre-flight checks
# ---------------------------------------------------------------------------
info "=== Graphify Explore Bootstrap ==="
info "Repo  : $REPO_ROOT"
info "Model : $MODEL"
info "Ollama: $OLLAMA_BASE_URL"
echo

command -v graphify  >/dev/null 2>&1 || die "graphify not found. Install with: uv tool install graphifyy"
command -v ollama    >/dev/null 2>&1 || warn "ollama CLI not found — assuming server is running separately"

# Check Ollama server is up
if ! curl -sf "${OLLAMA_BASE_URL%/v1}" >/dev/null 2>&1; then
    warn "Ollama server not reachable at ${OLLAMA_BASE_URL%/v1} — attempting to start..."
    ollama serve &>/dev/null &
    sleep 3
    curl -sf "${OLLAMA_BASE_URL%/v1}" >/dev/null 2>&1 || die "Ollama server still not reachable. Start it manually with: ollama serve"
fi

# Check the requested model is available
if ! ollama list 2>/dev/null | grep -q "${MODEL%%:*}"; then
    warn "Model '$MODEL' not found locally. Pulling..."
    ollama pull "$MODEL" || die "Failed to pull model '$MODEL'"
fi

success "Pre-flight checks passed"
echo

# ---------------------------------------------------------------------------
# 2. Extract — AST (local) + semantic (ollama)
# ---------------------------------------------------------------------------
info "Step 1/3 — Extracting knowledge graph..."
graphify . \
    --backend ollama \
    --model "$MODEL" \
    --token-budget "$TOKEN_BUDGET" \
    --max-concurrency "$MAX_CONCURRENCY"

echo
success "Extraction complete"

# ---------------------------------------------------------------------------
# 3. Cluster — name the communities
# ---------------------------------------------------------------------------
info "Step 2/3 — Clustering and naming communities..."
graphify cluster-only "$REPO_ROOT" \
    --backend ollama \
    --model "$MODEL"

echo
success "Communities named"

# ---------------------------------------------------------------------------
# 4. HTML visualizer
# ---------------------------------------------------------------------------
info "Step 3/3 — Generating interactive HTML visualizer..."
if graphify html "$REPO_ROOT" 2>/dev/null; then
    HTML_PATH="$REPO_ROOT/graphify-out/graph.html"
    success "Visualizer ready: $HTML_PATH"
    # Auto-open in browser (macOS)
    [[ "$OSTYPE" == "darwin"* ]] && open "$HTML_PATH"
else
    warn "graphify html not available in this version — skipping"
fi

# ---------------------------------------------------------------------------
# 5. Summary
# ---------------------------------------------------------------------------
echo
echo "============================================================"
echo "  Graph ready at: $REPO_ROOT/graphify-out/"
echo "============================================================"
echo
echo "  Query the graph:"
echo "    graphify query \"what is the entry point?\""
echo "    graphify query \"how does authentication work?\""
echo "    graphify path \"ClassA\" \"ClassB\""
echo "    graphify explain \"FunctionName\""
echo
echo "  Narrow results:"
echo "    graphify query \"your question\" --context-filter call"
echo "    graphify query \"your question\" --context-filter import"
echo
echo "  Wire into VSCode:"
echo "    graphify vscode install"
echo "============================================================"
