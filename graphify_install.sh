#!/usr/bin/env bash
# =============================================================================
# graphify_install.sh
# Run this ONCE on any new machine before using graphify_explore.sh
# Usage: bash graphify_install.sh
# =============================================================================

set -euo pipefail

info()    { echo "[install] $*"; }
success() { echo "[install] OK: $*"; }
warn()    { echo "[install] WARN: $*" >&2; }
die()     { echo "[install] ERROR: $*" >&2; exit 1; }

echo
echo "============================================================"
echo "  Graphify — One-time Install"
echo "============================================================"
echo

# ---------------------------------------------------------------------------
# 1. Homebrew (macOS only)
# ---------------------------------------------------------------------------
if [[ "$OSTYPE" == "darwin"* ]]; then
    if ! command -v brew &>/dev/null; then
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        success "Homebrew already installed: $(brew --version | head -1)"
    fi
fi

# ---------------------------------------------------------------------------
# 2. uv (fast Python package manager)
# ---------------------------------------------------------------------------
if ! command -v uv &>/dev/null; then
    info "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Reload PATH so uv is usable immediately
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
else
    success "uv already installed: $(uv --version)"
fi

# ---------------------------------------------------------------------------
# 3. Ollama
# ---------------------------------------------------------------------------
if ! command -v ollama &>/dev/null; then
    info "Installing Ollama..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install ollama
    else
        curl -fsSL https://ollama.com/install.sh | sh
    fi
else
    success "Ollama already installed: $(ollama --version)"
fi

# ---------------------------------------------------------------------------
# 4. graphify (with ollama extra)
# ---------------------------------------------------------------------------
if ! command -v graphify &>/dev/null; then
    info "Installing graphify with ollama support..."
    uv tool install "graphifyy[ollama]"
else
    info "graphify found — upgrading to latest with ollama support..."
    uv tool install "graphifyy[ollama]" --force
fi

# Verify
command -v graphify  &>/dev/null && success "graphify installed: $(graphify --version 2>/dev/null || echo 'ok')"
command -v graphify-mcp &>/dev/null && success "graphify-mcp installed"

# ---------------------------------------------------------------------------
# 5. Pull default Ollama models
# ---------------------------------------------------------------------------
echo
info "Pulling recommended Ollama models (skip with Ctrl+C if you have them)..."

DEFAULT_MODELS=(
    "qwen3.6:35b-mlx"     # best quality on M-series Mac (MLX accelerated)
    "gemma4:12b-mlx"      # lighter fallback
    "nomic-embed-text"    # embeddings (for --embeddings flag)
)

for model in "${DEFAULT_MODELS[@]}"; do
    if ollama list 2>/dev/null | grep -q "${model%%:*}"; then
        success "Model already present: $model"
    else
        info "Pulling $model ..."
        ollama pull "$model" || warn "Could not pull $model — skip and continue"
    fi
done

# ---------------------------------------------------------------------------
# 6. Shell env — add to ~/.zshrc
# ---------------------------------------------------------------------------
ZSHRC="$HOME/.zshrc"
MARKER="# --- graphify env ---"

if ! grep -q "$MARKER" "$ZSHRC" 2>/dev/null; then
    info "Adding graphify env vars to $ZSHRC..."
    cat >> "$ZSHRC" <<'EOF'

# --- graphify env ---
export OLLAMA_BASE_URL="http://localhost:11434/v1"
export OLLAMA_API_KEY="ollama"
export GRAPHIFY_OLLAMA_NUM_CTX="32768"
export GRAPHIFY_OLLAMA_KEEP_ALIVE="0"
EOF
    success "Env vars added to $ZSHRC"
    info "Run 'source ~/.zshrc' or open a new terminal to apply"
else
    success "graphify env vars already in $ZSHRC"
fi

# ---------------------------------------------------------------------------
# 7. VSCode integration (optional)
# ---------------------------------------------------------------------------
if command -v code &>/dev/null; then
    info "Wiring graphify into VSCode..."
    graphify vscode install && success "VSCode integration installed"
else
    warn "VSCode CLI (code) not found — skipping VSCode integration"
    info "To wire up later: graphify vscode install"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo
echo "============================================================"
echo "  Installation complete!"
echo "============================================================"
echo
echo "  Next steps:"
echo "    1. source ~/.zshrc          (or open a new terminal)"
echo "    2. ollama serve             (start Ollama if not running)"
echo "    3. cd <your-repo>"
echo "    4. bash graphify_explore.sh"
echo
echo "  Useful commands:"
echo "    graphify --version"
echo "    ollama list"
echo "    graphify query \"how does X work?\""
echo "============================================================"
