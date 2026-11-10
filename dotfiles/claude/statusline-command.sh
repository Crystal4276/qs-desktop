#!/usr/bin/env bash
input=$(cat)

# Debug : décommenter pour capturer un payload réel et inspecter .rate_limits
# echo "$input" > /tmp/statusline-payload.json

# ── Modèle + fenêtre de contexte ────────────────────────────────────────────

model=$(echo "$input" | jq -r '.model.display_name')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')

if [ "$ctx_size" -ge 900000 ] 2>/dev/null; then
  ctx_label="(1M context)"
else
  ctx_label=""
fi

# Pourcentage utilisé (pré-calculé par Claude Code)
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Tokens actifs dans la fenêtre de contexte courante
active_input=$(echo "$input" | jq -r '
  if .context_window.current_usage != null then
    (.context_window.current_usage.input_tokens // 0) +
    (.context_window.current_usage.cache_read_input_tokens // 0) +
    (.context_window.current_usage.cache_creation_input_tokens // 0)
  else 0 end
')

used_k=$(awk -v n="$active_input" 'BEGIN { printf "%.0fk", n / 1000 }')
total_k=$(awk -v n="$ctx_size"    'BEGIN { printf "%.0fk", n / 1000 }')

# Barre de progression contexte (16 blocs)
if [ -n "$used_pct" ]; then
  filled=$(awk -v p="$used_pct" 'BEGIN { printf "%.0f", p * 16 / 100 }')
  [ "$filled" -lt 0 ]  2>/dev/null && filled=0
  [ "$filled" -gt 16 ] 2>/dev/null && filled=16
  empty=$((16 - filled))

  bar=""
  for i in $(seq 1 "$filled"); do bar="${bar}#"; done
  for i in $(seq 1 "$empty");  do bar="${bar}-"; done

  pct_int=$(awk -v p="$used_pct" 'BEGIN { printf "%.0f", p }')

  if [ -n "$ctx_label" ]; then
    base=$(printf '%s %s | [%s] | %s%% | %s / %s' \
      "$model" "$ctx_label" "$bar" "$pct_int" "$used_k" "$total_k")
  else
    base=$(printf '%s | [%s] | %s%% | %s / %s' \
      "$model" "$bar" "$pct_int" "$used_k" "$total_k")
  fi
else
  # Pas encore de messages — afficher juste le modèle
  if [ -n "$ctx_label" ]; then
    base=$(printf '%s %s' "$model" "$ctx_label")
  else
    base=$(printf '%s' "$model")
  fi
fi

# ── Limites d'abonnement (rate_limits) ───────────────────────────────────────

# Couleur ANSI selon seuil : vert <50 %, jaune 50–80 %, rouge >80 %
_color() {
  local val
  val=$(awk -v p="$1" 'BEGIN { printf "%.0f", p }')
  if   [ "$val" -lt 50 ] 2>/dev/null; then printf '\033[32m'
  elif [ "$val" -le 80 ] 2>/dev/null; then printf '\033[33m'
  else printf '\033[31m'
  fi
}
RST=$'\033[0m'

# Abréviation française du jour (date -d @epoch '+%u' → 1=lun … 7=dim)
_day_fr() {
  local idx
  idx=$(date -d "@$1" '+%u' 2>/dev/null) || { echo "?"; return; }
  local days=("" "lun" "mar" "mer" "jeu" "ven" "sam" "dim")
  echo "${days[$idx]:-?}"
}

fh_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
fh_rst=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
wk_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
wk_rst=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

limits=""

if [ -n "$fh_pct" ]; then
  fh_int=$(awk -v p="$fh_pct" 'BEGIN { printf "%.0f", p }')
  fh_col=$(_color "$fh_pct")
  if [ -n "$fh_rst" ]; then
    fh_time=$(date -d "@$fh_rst" '+%H:%M' 2>/dev/null || echo "?")
    limits="${fh_col}5h ${fh_int}% (↻${fh_time})${RST}"
  else
    limits="${fh_col}5h ${fh_int}%${RST}"
  fi
fi

if [ -n "$wk_pct" ]; then
  wk_int=$(awk -v p="$wk_pct" 'BEGIN { printf "%.0f", p }')
  wk_col=$(_color "$wk_pct")
  if [ -n "$wk_rst" ]; then
    wk_day=$(_day_fr "$wk_rst")
    wk_seg="${wk_col}Sem ${wk_int}% (↻${wk_day})${RST}"
  else
    wk_seg="${wk_col}Sem ${wk_int}%${RST}"
  fi
  [ -n "$limits" ] && limits="${limits} | ${wk_seg}" || limits="$wk_seg"
fi

# ── Sortie finale ─────────────────────────────────────────────────────────────
if [ -n "$limits" ]; then
  printf '%s | %s' "$base" "$limits"
else
  printf '%s' "$base"
fi
