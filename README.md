# On any new machine — run once
bash graphify_install.sh

source ~/.zshrc

# On any repo you want to explore — drop in explore script and run

cd "repo"

bash graphify_explore.sh                   # default: qwen3.6:35b-mlx

bash graphify_explore.sh gemma4:12b-mlx   # or lighter model

TOKEN_BUDGET=8000 MAX_CONCURRENCY=2 bash graphify_explore.sh nemotron3:33b # for concurrent runs

# Cleanup, Pre-commit

echo "graphify-out/" >> .gitignore

echo ".graphify_analysis.json" >> .gitignore

git add .gitignore

git commit -m "add gitignore for graphify output artifacts"

git push
