#!/bin/bash
# Генерирует таблицу открытых PR пользователя Golopmoui3 для README профиля.
# Заполняет блок между маркерами <!-- PR-TABLE:START --> и <!-- PR-TABLE:END -->.
set -euo pipefail

OWNER="Golopmoui3"
README="${1:-README.md}"

open_prs=$(gh api "search/issues?q=type:pr+author:${OWNER}+is:open&per_page=50&sort=updated&order=desc" \
  --jq '.items[]
    | select(.pull_request != null)
    | [.number, .repository_url, .title, .html_url]
    | @tsv' 2>/dev/null || true)

table=""
if [ -n "$open_prs" ]; then
  table="| PR | Что чинит |"$'\n'"|---|---|"
  while IFS=$'\t' read -r number repo_url title html_url; do
    repo="${repo_url#https://api.github.com/repos/}"
    esc_title=$(printf '%s' "$title" | sed 's/|/\\|/g')
    table+=$'\n'"| [${repo}#${number}](${html_url}) | ${esc_title} |"
  done <<< "$open_prs"
else
  table="_Открытых PR сейчас нет — все смёржены или закрыты._"
fi

# Собираем новый README: всё до START, новая таблица, всё после END.
tmp=$(mktemp)
awk -v start='<!-- PR-TABLE:START -->' -v end='<!-- PR-TABLE:END -->' -v table="$table" '
  $0 == start { print; print ""; print table; print ""; inblock=1; next }
  $0 == end   { inblock=0; print; next }
  !inblock    { print }
' "$README" > "$tmp"

mv "$tmp" "$README"
echo "PR table updated: $(grep -c '^| \[' "$README" || true) PRs listed"
