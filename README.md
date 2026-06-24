# graphify-toolkit

Two shell scripts that get you from zero to a queryable knowledge graph on any codebase — fully local, no API costs, powered by [graphify](https://github.com/safishamsi/graphify) and [Ollama](https://ollama.com).

---

## What is graphify?

graphify turns any repo into a **queryable knowledge graph** — extracting classes, functions, imports, call graphs, and semantic relationships across your entire codebase. Instead of grepping files or stuffing everything into an LLM context window, your AI assistant navigates the graph directly.

- Code files → processed locally via Tree-sitter (zero API cost, nothing leaves your machine)
- Docs / markdown / PDFs → semantic extraction via your local Ollama model
- Output → `graph.json`, `GRAPH_REPORT.md`, and an interactive `graph.html` visualizer

---

## Scripts

| Script | Purpose | Run |
|---|---|---|
| `graphify_install.sh` | One-time setup on a new machine | `bash graphify_install.sh` |
| `graphify_explore.sh` | Build a knowledge graph for any repo | `bash graphify_explore.sh` |

---

## Quickstart

### Step 1 — Install once per machine

```bash
git clone https://github.com/AvinashAnad/graphify-toolkit.git
cd graphify-toolkit
bash graphify_install.sh
source ~/.zshrc
```

This installs:
- [Homebrew](https://brew.sh) (macOS only, if missing)
- [uv](https://github.com/astral-sh/uv) — fast Python package manager
- [Ollama](https://ollama.com) — local LLM runtime
- `graphifyy[ollama]` — graphify with Ollama backend support
- Recommended models: `qwen3.6:35b-mlx`, `gemma4:12b-mlx`, `nomic-embed-text`
- Graphify env vars written to `~/.zshrc`
- VSCode integration (if `code` CLI is available)

---

### Step 2 — Explore any repo

Copy `graphify_explore.sh` into the root of any repo and run it:

```bash
cd your-repo/
cp /path/to/graphify-toolkit/graphify_explore.sh .
bash graphify_explore.sh
```

Or pass a different model:

```bash
bash graphify_explore.sh gemma4:12b-mlx
```

Or override settings inline:

```bash
TOKEN_BUDGET=8000 MAX_CONCURRENCY=2 bash graphify_explore.sh nemotron3:33b
```

The script runs 3 steps automatically:

1. **Extract** — AST on all code files (local) + semantic extraction on docs via Ollama
2. **Cluster** — names the 100+ communities so the report is readable
3. **Visualize** — generates `graphify-out/graph.html` and opens it in your browser

---

## Querying the graph

Once extraction is complete, query from the terminal:

```bash
# Natural language questions
graphify query "what is the entry point of this project?"
graphify query "how does authentication work?"
graphify query "which modules handle error propagation?"

# Structural traversal
graphify path "ClassA" "ClassB"
graphify explain "FunctionName"

# Narrow results by relationship type
graphify query "your question" --context-filter call
graphify query "your question" --context-filter import
```

---

## VSCode integration

```bash
graphify vscode install
```

Then in any VSCode AI chat (Copilot, Continue, etc.):

```
/graphify how does the DAG orchestration work?
```

---

## Models

Tested on Apple Silicon (M1 Max / M-series) with MLX-accelerated models:

| Model | Size | Notes |
|---|---|---|
| `qwen3.6:35b-mlx` | 21 GB | Best quality, default |
| `gemma4:12b-mlx` | 23 GB | Good lighter alternative |
| `gemma4:31b-mlx` | 20 GB | High quality, more VRAM |
| `nemotron3:33b` | 27 GB | Strong for code-heavy repos |
| `nomic-embed-text` | 274 MB | Embeddings only (`--embeddings` flag) |

---

## Environment variables

Set automatically by `graphify_install.sh` in `~/.zshrc`:

```bash
export OLLAMA_BASE_URL="http://localhost:11434/v1"
export OLLAMA_API_KEY="ollama"          # dummy value, Ollama doesn't need auth
export GRAPHIFY_OLLAMA_NUM_CTX="32768"  # context window — critical for Ollama
export GRAPHIFY_OLLAMA_KEEP_ALIVE="0"   # resets session between chunks
```

---

## Output files

After running `graphify_explore.sh`, the `graphify-out/` directory contains:

| File | Description |
|---|---|
| `graph.json` | Queryable knowledge graph (nodes + edges + communities) |
| `GRAPH_REPORT.md` | Human-readable community map with Obsidian-compatible links |
| `graph.html` | Interactive vis.js visualizer |
| `.graphify_analysis.json` | Extraction metadata and token usage |
| `cost.json` | Token usage and estimated cost per run |

> `graphify-out/` is gitignored — it is generated per machine and not committed.

---

## Troubleshooting

**Empty responses / 0 nodes after extraction**
Ollama's default context window is 2048 tokens. The `GRAPHIFY_OLLAMA_NUM_CTX` env var overrides this. Make sure it is exported before running.

**`graphify: command not found` after install**
```bash
source ~/.zshrc
# or
export PATH="$HOME/.local/bin:$PATH"
```

**Ollama server not running**
```bash
ollama serve
```

**Re-run extraction after adding new files**
```bash
graphify . --backend ollama --model qwen3.6:35b-mlx
```
Cached files are skipped automatically — only new or changed files are re-extracted.

---

## References

- [graphify on GitHub](https://github.com/safishamsi/graphify)
- [graphify PyPI package](https://pypi.org/project/graphifyy/)
- [Ollama](https://ollama.com)
- [graphify VSCode extension](https://marketplace.visualstudio.com/items?itemName=AnytechieStudio.graphify-vscode)
