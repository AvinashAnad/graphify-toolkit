# On any new machine — run once
bash graphify_install.sh

source ~/.zshrc

# On any repo you want to explore — drop in explore script and run
cd <your-repo>

bash graphify_explore.sh                   # default: qwen3.6:35b-mlx

bash graphify_explore.sh gemma4:12b-mlx   # or lighter model

TOKEN_BUDGET=8000 MAX_CONCURRENCY=2 bash graphify_explore.sh nemotron3:33b # for concurrent runs
