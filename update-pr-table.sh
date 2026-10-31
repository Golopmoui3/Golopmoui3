#!/bin/bash
# Генерирует таблицу PR пользователя Golopmoui3 для README профиля (открытые и смёрженные в upstream).
# Заполняет блок между маркерами <!-- PR-TABLE:START --> и <!-- PR-TABLE:END -->.
set -euo pipefail

OWNER="Golopmoui3"
README="${1:-README.md}"

# Открытые PR (в ревью)
open_prs=$(gh api "search/issues?q=type:pr+author:${OWNER}+is:open&per_page=50&sort=updated&order=desc" \
  --jq '.items[]
    | select(.pull_request != null)
    | [.number, .repository_url, .title, .html_url]
    | @tsv' 2>/dev/null || true)

# Смёрженные PR в upstream (исключая собственные репозитории)
merged_prs=$(gh api "search/issues?q=type:pr+author:${OWNER}+is:merged+-user:${OWNER}&per_page=50&sort=updated&order=desc" \
  --jq '.items[]
    | select(.pull_request != null)
    | [.number, .repository_url, .title, .html_url]
    | @tsv' 2>/dev/null || true)

table=""

# Секция открытых PR
table+="### 🚀 На рассмотрении в Upstream (Open PRs)"$'\n\n'
if [ -n "$open_prs" ]; then
  table+="| PR | Что чинит |"$'\n'"|---|---|"
  while IFS=$'\t' read -r number repo_url title html_url; do
    repo="${repo_url#https://api.github.com/repos/}"
    esc_title=$(printf '%s' "$title" | sed 's/|/\\|/g')
    table+=$'\n'"| [${repo}#${number}](${html_url}) | ${esc_title} |"
  done <<< "$open_prs"
else
  table+="_Открытых PR сейчас нет — всё смёржено или в разработке._"
fi

# Секция смёрженных PR
table+=$'\n\n'"### ✅ Принятые в Upstream (Merged PRs)"$'\n\n'
if [ -n "$merged_prs" ]; then
  table+="| PR | Репозиторий / Что сделано |"$'\n'"|---|---|"
  while IFS=$'\t' read -r number repo_url title html_url; do
    repo="${repo_url#https://api.github.com/repos/}"
    esc_title=$(printf '%s' "$title" | sed 's/|/\\|/g')
    table+=$'\n'"| [${repo}#${number}](${html_url}) | ${esc_title} |"
  done <<< "$merged_prs"
else
  table+="_Пока нет смёрженных PR._"
fi

# Собираем новый README: всё до START, новый блок, всё после END.
tmp=$(mktemp)
awk -v start='<!-- PR-TABLE:START -->' -v end='<!-- PR-TABLE:END -->' -v table="$table" '
  {
    line = $0
    sub(/\r$/, "", line)
  }
  line == start { print start; print ""; print table; print ""; inblock=1; next }
  line == end   { inblock=0; print end; next }
  !inblock      { print $0 }
' "$README" > "$tmp"

mv "$tmp" "$README"
echo "PR table updated successfully."
