#!/usr/bin/env bash
set -euo pipefail

# =====================================
# SouqStationStore Interactive CLI (bash)
# =====================================

# -------------------------
# Config (env defaults)
# -------------------------
: "${PUBLISHER_URL:=http://localhost:8082}"
: "${PLATFORM_URL:=http://localhost:8081}"
: "${NOTIF_URL:=http://localhost:8083}"

# -------------------------
# Session
# -------------------------
CURRENT_EMAIL=""
CURRENT_USER_ID=""
CURRENT_ROLE="NONE"  # NONE | USER | REDACTOR

# -------------------------
# Utils
# -------------------------
pause() { read -r -p "Appuyez sur Entrée..." _; }

banner() {
  clear || true
  echo "====================================="
  echo "     SouqStation Interactive CLI"
  echo "====================================="
  if [[ "$CURRENT_ROLE" == "NONE" ]]; then
    echo "Non connecté"
  else
    echo "Connecté en tant que: ${CURRENT_EMAIL} [${CURRENT_ROLE}] (userId=${CURRENT_USER_ID})"
  fi
  echo "-------------------------------------"
}

prompt() {
  local label="$1"
  local default="${2:-}"
  local v=""
  if [[ -n "$default" ]]; then
    read -r -p "${label} [${default}]: " v
    if [[ -z "${v// }" ]]; then
      echo "$default"
    else
      echo "$v"
    fi
  else
    read -r -p "${label}: " v
    echo "$v"
  fi
}

# URL encode (portable via python3 if present, fallback: raw)
urlencode() {
  local s="${1:-}"
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY' "$s"
import sys, urllib.parse
print(urllib.parse.quote_plus(sys.argv[1]))
PY
  else
    # fallback minimal (pas parfait)
    echo "$s"
  fi
}

# pretty JSON if jq installed
print_json() {
  if command -v jq >/dev/null 2>&1; then
    echo "$1" | jq .
  else
    echo "$1"
  fi
}

# HTTP helpers (form-urlencoded)
http_get() {
  local url="$1"
  curl -sS -f "$url"
}

http_post_form() {
  local url="$1"; shift
  # args are key=value already urlencoded or raw (curl encode recommended with --data-urlencode)
  curl -sS -f -X POST "$url" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data "$*"
}

# safer post: build with --data-urlencode pairs (recommended)
# usage: http_post_form_kv "$url" key val key val ...
http_post_form_kv() {
  local url="$1"; shift
  local args=()
  while (( "$#" )); do
    local k="$1"; local v="${2:-}"; shift 2
    args+=( --data-urlencode "${k}=${v}" )
  done
  curl -sS -f -X POST "$url" -H "Content-Type: application/x-www-form-urlencoded" "${args[@]}"
}

# multi values: pass list values for a given key
# usage: http_post_form_multi "$url" key val ... --multi modifications "A,B,C"
http_post_form_multi() {
  local url="$1"; shift
  local args=()
  # parse until --multi
  while (( "$#" )); do
    if [[ "$1" == "--multi" ]]; then
      shift
      break
    fi
    local k="$1"; local v="${2:-}"; shift 2
    args+=( --data-urlencode "${k}=${v}" )
  done

  # multi part: pairs key "v1,v2,v3" (comma-separated)
  while (( "$#" )); do
    local mk="$1"; local mv="${2:-}"; shift 2
    IFS=',' read -r -a arr <<< "$mv"
    for it in "${arr[@]}"; do
      it="${it#"${it%%[![:space:]]*}"}"; it="${it%"${it##*[![:space:]]}"}"
      [[ -z "$it" ]] && continue
      args+=( --data-urlencode "${mk}=${it}" )
    done
  done

  curl -sS -f -X POST "$url" -H "Content-Type: application/x-www-form-urlencoded" "${args[@]}"
}

show_http_error() {
  local rc=$1
  echo "HTTP Error (curl exit code: $rc)"
}

# -------------------------
# Register
# -------------------------
action_register_user() {
  local userId name email displayName birth solde
  userId="$(prompt "ID_Utilisateur" "user-1")"
  name="$(prompt "nom" "John Doe")"
  email="$(prompt "email" "user@test.com")"
  displayName="$(prompt "pseudo" "JohnD")"
  birth="$(prompt "Date de naissance (AAAA-MM-JJ)" "1990-01-01")"
  solde="$(prompt "solde" "0.0")"

  local url="${PLATFORM_URL}/platform/register-user"
  set +e
  local resp
  resp="$(http_post_form_kv "$url" \
    userId "$userId" name "$name" email "$email" displayName "$displayName" birth "$birth" solde "$solde" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  print_json "$resp"
  echo "Utilisateur créé"
  pause
}

action_register_redactor() {
  local userId name email displayName birth solde individual
  userId="$(prompt "userId" "redactor-1")"
  name="$(prompt "nom" "Jane Doe")"
  email="$(prompt "email" "redactor@test.com")"
  displayName="$(prompt "pseudo" "JaneD")"
  birth="$(prompt "Date de naissance (AAAA-MM-JJ)" "1985-01-01")"
  solde="$(prompt "solde" "0.0")"
  individual="$(prompt "Particulier (true/false)" "true")"

  local url="${PLATFORM_URL}/platform/register-redactor"
  set +e
  local resp
  resp="$(http_post_form_kv "$url" \
    userId "$userId" name "$name" email "$email" displayName "$displayName" birth "$birth" solde "$solde" individual "$individual" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  print_json "$resp"
  echo "Éditeur créé"
  pause
}

# -------------------------
# Connexion / Déconnexion
# -------------------------
connexion() {
  local email
  email="$(prompt "email" "redactor@test.com")"

  local checkUrl="${PLATFORM_URL}/platform/users/check-email?email=$(urlencode "$email")"
  set +e
  local r
  r="$(http_get "$checkUrl" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$r"; pause; return; fi

  # expects JSON { exists: true/false, userId: "..." }
  local exists userId
  if command -v jq >/dev/null 2>&1; then
    exists="$(echo "$r" | jq -r '.exists // false')"
    userId="$(echo "$r" | jq -r '.userId // ""')"
  else
    # fallback naive
    exists="$(echo "$r" | grep -qi '"exists"[[:space:]]*:[[:space:]]*true' && echo true || echo false)"
    userId="$(echo "$r" | sed -n 's/.*"userId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  fi

  if [[ "$exists" != "true" ]]; then
    echo "Utilisateur introuvable"
    pause
    return
  fi

  CURRENT_EMAIL="$email"
  CURRENT_USER_ID="$userId"

  local redUrl="${PLATFORM_URL}/platform/redactors/exists?userId=$(urlencode "$CURRENT_USER_ID")"
  set +e
  local rr
  rr="$(http_get "$redUrl" 2>&1)"
  rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$rr"; pause; return; fi

  local isRed
  if command -v jq >/dev/null 2>&1; then
    isRed="$(echo "$rr" | jq -r '.exists // false')"
  else
    isRed="$(echo "$rr" | grep -qi '"exists"[[:space:]]*:[[:space:]]*true' && echo true || echo false)"
  fi

  if [[ "$isRed" == "true" ]]; then
    CURRENT_ROLE="REDACTOR"
    echo "Bienvenue éditeur"
    # count published games (optional)
    set +e
    local countUrl="${PUBLISHER_URL}/publisher/games/count?idEditeur=$(urlencode "$CURRENT_USER_ID")"
    local countResp
    countResp="$(http_get "$countUrl" 2>/dev/null)"
    if [[ -n "$countResp" ]]; then
      echo "You published ${countResp} games"
    fi
    set -e
  else
    CURRENT_ROLE="USER"
    echo "Bienvenue utilisateur"
  fi

  pause
}

deconnexion() {
  CURRENT_EMAIL=""
  CURRENT_USER_ID=""
  CURRENT_ROLE="NONE"
  echo "Déconnecté"
  pause
}

# -------------------------
# Social
# -------------------------
follow_user() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return

  local followedId
  followedId="$(prompt "ID de l'utilisateur à suivre" "U200")"
  if [[ "$followedId" == "$CURRENT_USER_ID" ]]; then
    echo "Vous ne pouvez pas vous suivre vous-même."
    pause
    return
  fi

  local url="${PLATFORM_URL}/platform/users/follow"
  set +e
  local resp
  resp="$(http_post_form_kv "$url" userId "$CURRENT_USER_ID" followedId "$followedId" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  print_json "$resp"
  echo "Vous suivez maintenant $followedId"
  pause
}

show_following() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return

  local url="${PLATFORM_URL}/platform/users/following?userId=$(urlencode "$CURRENT_USER_ID")"
  set +e
  local resp
  resp="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  if command -v jq >/dev/null 2>&1; then
    local count
    count="$(echo "$resp" | jq 'length')"
    if [[ "$count" == "0" ]]; then
      echo "Aucun abonnement pour le moment."
    else
      echo ""
      echo "Abonnements:"
      echo "$resp" | jq -r '.[] | "----------------------\nuserId: \(.userId)\n" + (if .displayName then "displayNom: \(.displayName)\n" else "" end)'
    fi
  else
    echo "$resp"
  fi
  pause
}

follow_redactor() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Connexion first" && pause && return
  local redactorId
  redactorId="$(prompt "ID de l'éditeur à suivre" "redactor-1")"

  local url="${PLATFORM_URL}/platform/users/follow-redactor"
  set +e
  local resp
  resp="$(http_post_form_kv "$url" userId "$CURRENT_USER_ID" redactorId "$redactorId" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  print_json "$resp"
  echo "Éditeur suivi $redactorId"
  pause
}

show_followed_redactors() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Connexion first" && pause && return

  local url="${PLATFORM_URL}/platform/users/following-redactors?userId=$(urlencode "$CURRENT_USER_ID")"
  set +e
  local resp
  resp="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  if command -v jq >/dev/null 2>&1; then
    local count
    count="$(echo "$resp" | jq 'length')"
    if [[ "$count" == "0" ]]; then
      echo "Aucun éditeur suivi"
    else
      echo "Éditeurs que vous suivez:"
      echo "$resp" | jq -r '.[] | "----------------\nId: \(.userId)\nNom: \(.displayName)\n"'
    fi
  else
    echo "$resp"
  fi
  pause
}

show_games_of_followed_editor() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Connexion first" && pause && return

  local editorsUrl="${PLATFORM_URL}/platform/users/following-redactors?userId=$(urlencode "$CURRENT_USER_ID")"
  set +e
  local editors
  editors="$(http_get "$editorsUrl" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$editors"; pause; return; fi

  if command -v jq >/dev/null 2>&1; then
    local cnt
    cnt="$(echo "$editors" | jq 'length')"
    if [[ "$cnt" == "0" ]]; then
      echo "Vous ne suivez encore aucun éditeur."
      pause
      return
    fi

    echo ""
    echo "Éditeurs que vous suivez:"
    echo "$editors" | jq -r 'to_entries[] | "\(.key+1)) \(.value.displayName) (\(.value.userId))"'

    local choice editorId
    choice="$(prompt "Entrez le numéro ou l'ID de l'éditeur" "1")"
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
      local idx=$((choice-1))
      editorId="$(echo "$editors" | jq -r --argjson i "$idx" '.[$i].userId')"
      if [[ -z "$editorId" || "$editorId" == "null" ]]; then
        echo "Numéro invalide"
        pause
        return
      fi
    else
      editorId="$choice"
    fi

    local gamesUrl="${PUBLISHER_URL}/publisher/games/by-publisher?idEditeur=$(urlencode "$editorId")"
    set +e
    local games
    games="$(http_get "$gamesUrl" 2>&1)"
    rc=$?
    set -e
    if (( rc != 0 )); then show_http_error "$rc"; echo "$games"; pause; return; fi

    echo ""
    echo "Jeux publiés par $editorId:"
    local gc
    gc="$(echo "$games" | jq 'length')"
    if [[ "$gc" == "0" ]]; then
      echo "Aucun jeu trouvé."
      pause
      return
    fi

    echo "$games" | jq -r '.[] |
      "----------------------\n\(.title) (\(.gameId))\nPlateforme: \(.platform)\nGenre: \(.genre)\nVersion: \(.version)\n" +
      (if .price!=null then "Prix: \(.price)\n" else "" end) +
      (if .releaseDate!=null then "Date de sortie: \(.releaseDate)\n" else "" end)
    '
  else
    echo "jq recommandé pour cette commande."
    echo "$editors"
  fi

  pause
}

# -------------------------
# Publisher (redactor)
# -------------------------
publish_game() {
  [[ "$CURRENT_ROLE" != "REDACTOR" ]] && echo "La publication est réservée aux ÉDITEURS." && pause && return

  local gameId title description platform genre version releaseDate price
  gameId="$(prompt "ID_Jeu" "game-100")"
  title="$(prompt "titre" "Halo")"
  description="$(prompt "description" "")"
  platform="$(prompt "Plateforme (PC/SWITCH/WEB)" "PC")"; platform="${platform^^}"
  genre="$(prompt "Genre (ACTION/RPG/STRATEGY)" "ACTION")"; genre="${genre^^}"
  version="$(prompt "version" "1.0.0")"
  releaseDate="$(prompt "Date de sortie (AAAA-MM-JJ)" "2026-01-01")"
  price="$(prompt "prix initial (optionnel)" "")"

  local url="${PUBLISHER_URL}/publisher/publish-game"
  set +e
  local resp
  if [[ -n "$price" ]]; then
    resp="$(http_post_form_kv "$url" \
      gameId "$gameId" title "$title" description "$description" platform "$platform" genre "$genre" \
      idEditeur "$CURRENT_USER_ID" version "$version" releaseDate "$releaseDate" \
      price "$price" prixInit "$price" 2>&1)"
  else
    resp="$(http_post_form_kv "$url" \
      gameId "$gameId" title "$title" description "$description" platform "$platform" genre "$genre" \
      idEditeur "$CURRENT_USER_ID" version "$version" releaseDate "$releaseDate" 2>&1)"
  fi
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  print_json "$resp"
  echo "Game published"
  pause
}

my_games() {
  [[ "$CURRENT_ROLE" != "REDACTOR" ]] && echo "Mes jeux is only for REDACTOR." && pause && return

  local url="${PUBLISHER_URL}/publisher/games/by-publisher?idEditeur=$(urlencode "$CURRENT_USER_ID")"
  set +e
  local resp
  resp="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  if command -v jq >/dev/null 2>&1; then
    local count
    count="$(echo "$resp" | jq 'length')"
    if [[ "$count" == "0" ]]; then
      echo "Aucun jeu pour l'instant"
    else
      echo "$resp" | jq -r '.[] | "----------------------\n\(.title) (\(.gameId))\nPlateforme: \(.platform)\nGenre: \(.genre)\nVersion: \(.version)\n"'
    fi
  else
    echo "$resp"
  fi
  pause
}

publish_patch() {
  [[ "$CURRENT_ROLE" != "REDACTOR" ]] && echo "Réservé aux ÉDITEURS." && pause && return

  local gameId targetVersion patchNotes releasedAt modsRaw
  gameId="$(prompt "GameId" "G300")"
  targetVersion="$(prompt "Target version" "1.0.1")"
  patchNotes="$(prompt "Patch notes" "Correction du crash sous Windows 11")"
  releasedAt="$(prompt "ReleasedAt (AAAA-MM-JJ)" "2025-11-20")"
  modsRaw="$(prompt "Modifications (séparées par virgule)" "CORRECTION,OPTIMISATION")"

  local url="${PUBLISHER_URL}/publisher/publish-patch"
  set +e
  local resp
  resp="$(http_post_form_multi "$url" \
    gameId "$gameId" targetVersion "$targetVersion" patchNotes "$patchNotes" releasedAt "$releasedAt" \
    --multi modifications "$modsRaw" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  print_json "$resp"
  echo "Patch publié"
  pause
}

list_patches_for_game() {
  [[ "$CURRENT_ROLE" != "REDACTOR" ]] && echo "Réservé aux ÉDITEURS." && pause && return
  local gameId
  gameId="$(prompt "GameId" "G300")"

  local url="${PUBLISHER_URL}/publisher/games/$(urlencode "$gameId")/patches"
  set +e
  local resp
  resp="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  print_json "$resp"
  pause
}

publish_dlc() {
  [[ "$CURRENT_ROLE" != "REDACTOR" ]] && echo "Réservé aux ÉDITEURS." && pause && return

  local gameId dlcId title desc price releasedAt
  gameId="$(prompt "GameId" "G300")"
  dlcId="$(prompt "DlcId" "DLC-1")"
  title="$(prompt "Titre DLC" "Expansion Pack")"
  desc="$(prompt "Description" "Nouveau contenu")"
  price="$(prompt "Prix" "9.99")"
  releasedAt="$(prompt "ReleasedAt (AAAA-MM-JJ)" "2025-12-01")"

  local url="${PUBLISHER_URL}/publisher/publish-dlc"
  set +e
  local resp
  resp="$(http_post_form_kv "$url" \
    gameId "$gameId" dlcId "$dlcId" name "$title" description "$desc" price "$price" publisherId "$CURRENT_USER_ID" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  print_json "$resp"
  echo "DLC publié"
  pause
}

list_dlcs_for_game_publisher() {
  [[ "$CURRENT_ROLE" != "REDACTOR" ]] && echo "Réservé aux ÉDITEURS." && pause && return
  local gameId
  gameId="$(prompt "GameId" "G300")"

  local url="${PUBLISHER_URL}/publisher/games/$(urlencode "$gameId")/dlcs"
  set +e
  local resp
  resp="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  print_json "$resp"
  pause
}

# -------------------------
# Catalog (platform)
# -------------------------
catalog_list_games() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return

  local genre platform maxPrice promoOnly
  genre="$(prompt "Filtre genre (optionnel)" "")"; genre="${genre^^}"
  platform="$(prompt "Filtre plateforme (optionnel)" "")"; platform="${platform^^}"
  maxPrice="$(prompt "Filtre prix max (optionnel)" "")"
  promoOnly="$(prompt "Voir uniquement les promotions (o/n)" "n")"; promoOnly="${promoOnly,,}"

  local qs=()
  [[ -n "$genre" ]] && qs+=( "genre=$(urlencode "$genre")" )
  [[ -n "$platform" ]] && qs+=( "platform=$(urlencode "$platform")" )
  [[ -n "$maxPrice" ]] && qs+=( "maxPrice=$(urlencode "$maxPrice")" )
  local query=""
  ((${#qs[@]})) && query="?$(
    IFS='&'; echo "${qs[*]}"
  )"

  local url="${PLATFORM_URL}/platform/catalog/games${query}"
  set +e
  local resp
  resp="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  if command -v jq >/dev/null 2>&1; then
    local items
    if [[ "$promoOnly" == "o" || "$promoOnly" == "y" ]]; then
      items="$(echo "$resp" | jq '.games | map(select((.description // "") | test("\\[PROMOTION\\]")) )')"
    else
      items="$(echo "$resp" | jq '.games')"
    fi

    local count
    count="$(echo "$items" | jq 'length')"
    if [[ "$count" == "0" ]]; then
      echo "Aucun jeu dans le catalogue."
    else
      local total
      total="$(echo "$resp" | jq -r '.totalGames // "?"')"
      echo "Catalogue: ${total} jeu(x)"
      echo "$items" | jq -r '.[] |
        "----------------------\n\(.title) (\(.gameId))\n" +
        (if .platform then "Plateforme: \(.platform)\n" else "" end) +
        (if .genre then "Genre: \(.genre)\n" else "" end) +
        (if .price!=null then "Prix: \(.price)\n" else "" end) +
        (if .releaseDate then "Sortie: \(.releaseDate)\n" else "" end)
      '
    fi
  else
    echo "$resp"
  fi

  pause
}

catalog_game_details() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local gameId
  gameId="$(prompt "GameId" "G300")"

  local url="${PLATFORM_URL}/platform/catalog/games/$(urlencode "$gameId")"
  set +e
  local resp
  resp="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  print_json "$resp"
  pause
}

# -------------------------
# Purchases & Library
# -------------------------
buy_game() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local gameId
  gameId="$(prompt "GameId à acheter" "G300")"

  local url="${PLATFORM_URL}/platform/purchases/game"
  set +e
  local resp
  resp="$(http_post_form_kv "$url" userId "$CURRENT_USER_ID" gameId "$gameId" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  print_json "$resp"
  echo "Achat effectué (si solde/conditions OK)"
  pause
}

my_library() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local url="${PLATFORM_URL}/platform/purchases/library?userId=$(urlencode "$CURRENT_USER_ID")"

  set +e
  local resp
  resp="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  print_json "$resp"
  pause
}

buy_dlc() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local gameId dlcId
  gameId="$(prompt "GameId" "G300")"
  dlcId="$(prompt "DlcId" "DLC-1")"

  local url="${PLATFORM_URL}/platform/purchases/dlc"
  set +e
  local resp
  resp="$(http_post_form_kv "$url" userId "$CURRENT_USER_ID" gameId "$gameId" dlcId "$dlcId" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  print_json "$resp"
  echo "Achat DLC effectué (si OK)"
  pause
}

my_dlcs() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local url="${PLATFORM_URL}/platform/purchases/dlc-library?userId=$(urlencode "$CURRENT_USER_ID")"

  set +e
  local resp
  resp="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  print_json "$resp"
  pause
}

check_ownership() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local gameId
  gameId="$(prompt "GameId" "G300")"

  local url="${PLATFORM_URL}/platform/purchases/owns?userId=$(urlencode "$CURRENT_USER_ID")&gameId=$(urlencode "$gameId")"
  set +e
  local resp
  resp="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  print_json "$resp"
  pause
}

game_sales_count() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local gameId
  gameId="$(prompt "GameId" "G300")"

  local url="${PLATFORM_URL}/platform/purchases/sales-count?gameId=$(urlencode "$gameId")"
  set +e
  local resp
  resp="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  print_json "$resp"
  pause
}

# -------------------------
# Reviews
# -------------------------
submit_review() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local gameId note desc
  gameId="$(prompt "GameId" "G300")"
  note="$(prompt "Note (0-10)" "9")"
  desc="$(prompt "Description" "Incroyable !")"

  local url="${PLATFORM_URL}/platform/reviews/submit"
  set +e
  local resp
  resp="$(http_post_form_kv "$url" userId "$CURRENT_USER_ID" gameId "$gameId" note "$note" description "$desc" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  print_json "$resp"
  echo "Avis envoyé"
  pause
}

rate_review_helpful() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local reviewId isHelpful
  reviewId="$(prompt "ReviewId" "")"
  [[ -z "${reviewId// }" ]] && echo "ReviewId requis" && pause && return
  isHelpful="$(prompt "Utile ? (true/false)" "true")"; isHelpful="${isHelpful,,}"

  local url="${PLATFORM_URL}/platform/reviews/$(urlencode "$reviewId")/rate"
  set +e
  local resp
  resp="$(http_post_form_kv "$url" userId "$CURRENT_USER_ID" isHelpful "$isHelpful" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  print_json "$resp"
  echo "Vote enregistré"
  pause
}

list_reviews_by_game() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local gameId
  gameId="$(prompt "GameId" "G300")"

  local url="${PLATFORM_URL}/platform/reviews/game/$(urlencode "$gameId")"
  set +e
  local resp
  resp="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi
  print_json "$resp"
  pause
}

list_reviews_by_user() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local userId
  userId="$(prompt "UserId (laisser vide = moi)" "")"
  [[ -z "${userId// }" ]] && userId="$CURRENT_USER_ID"

  local url="${PLATFORM_URL}/platform/reviews/user/$(urlencode "$userId")"
  set +e
  local resp
  resp="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi
  print_json "$resp"
  pause
}

# -------------------------
# Incidents
# -------------------------
report_incident() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return

  local gameId severity desc envt
  gameId="$(prompt "GameId" "G300")"
  severity="$(prompt "Sévérité (HAUTE/NORMALE/BASSE/CRITIQUE)" "HAUTE")"; severity="${severity^^}"
  desc="$(prompt "Description" "Crashs intempestifs")"
  envt="$(prompt "Environment" "Windows 11")"

  local url="${PLATFORM_URL}/platform/incidents/report"
  set +e
  local resp
  resp="$(http_post_form_kv "$url" \
    userId "$CURRENT_USER_ID" gameId "$gameId" severity "$severity" description "$desc" environment "$envt" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  print_json "$resp"
  echo "Incident signalé"
  pause
}

list_incidents_by_game() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local gameId severity
  gameId="$(prompt "GameId" "G300")"
  severity="$(prompt "Filtre sévérité (optionnel)" "")"; severity="${severity^^}"

  local q=""
  [[ -n "$severity" ]] && q="?severity=$(urlencode "$severity")"
  local url="${PLATFORM_URL}/platform/incidents/game/$(urlencode "$gameId")${q}"

  set +e
  local resp
  resp="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi
  print_json "$resp"
  pause
}

count_incidents_by_game() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local gameId
  gameId="$(prompt "GameId" "G300")"

  local url="${PLATFORM_URL}/platform/incidents/game/$(urlencode "$gameId")/count"
  set +e
  local resp
  resp="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi
  print_json "$resp"
  pause
}

# -------------------------
# Notifications
# -------------------------
my_notifications() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local url="${NOTIF_URL}/notifications/$(urlencode "$CURRENT_USER_ID")"

  set +e
  local resp
  resp="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi
  print_json "$resp"
  pause
}

create_notification_test() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local type msg
  type="$(prompt "Type" "TEST_NOTIF")"
  msg="$(prompt "Message" "Ceci est un test")"

  local url="${NOTIF_URL}/notifications/send"
  set +e
  local resp
  resp="$(http_post_form_kv "$url" userId "$CURRENT_USER_ID" type "$type" message "$msg" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi
  echo "Notification créée avec succès!"
  print_json "$resp"
  pause
}

# -------------------------
# Gameplay Sessions
# -------------------------
start_game_session() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local gameId
  gameId="$(prompt "GameId" "G300")"

  local url="${PLATFORM_URL}/platform/sessions/start"
  set +e
  local resp
  resp="$(http_post_form_kv "$url" userId "$CURRENT_USER_ID" gameId "$gameId" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi
  print_json "$resp"
  echo "Session démarrée"
  pause
}

end_game_session() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local gameId
  gameId="$(prompt "GameId" "G300")"

  local url="${PLATFORM_URL}/platform/sessions/end"
  set +e
  local resp
  resp="$(http_post_form_kv "$url" userId "$CURRENT_USER_ID" gameId "$gameId" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi
  print_json "$resp"
  echo "Session terminée"
  pause
}

my_playtime() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local gameId
  gameId="$(prompt "GameId (optionnel, vide = tout)" "")"
  local q=""
  [[ -n "${gameId// }" ]] && q="?gameId=$(urlencode "$gameId")"

  local url="${PLATFORM_URL}/platform/sessions/users/$(urlencode "$CURRENT_USER_ID")/playtime${q}"
  set +e
  local resp
  resp="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi
  print_json "$resp"
  pause
}

# -------------------------
# Feedback Aggregation
# -------------------------
feedback_get_reviews() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local gameId minNote sort page size
  gameId="$(prompt "GameId" "G300")"
  minNote="$(prompt "Note minimale (minNote)" "0")"
  sort="$(prompt "Tri (asc|desc) (submittedAt)" "desc")"
  page="$(prompt "Page" "0")"
  size="$(prompt "Taille (size)" "20")"

  local url="${PLATFORM_URL}/platform/feedback/reviews?gameId=$(urlencode "$gameId")&minNote=$(urlencode "$minNote")&sort=$(urlencode "$sort")&page=$(urlencode "$page")&size=$(urlencode "$size")"
  set +e
  local resp
  resp="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  if command -v jq >/dev/null 2>&1; then
    echo ""
    echo "$resp" | jq -r '"TotalElements: \(.totalElements) | TotalPages: \(.totalPages) | Page: \(.number)"'
    local c
    c="$(echo "$resp" | jq '.content | length')"
    if [[ "$c" == "0" ]]; then
      echo "Aucun avis."
    else
      echo "$resp" | jq -r '.content[] |
        "----------------------\n" +
        (if .reviewId then "reviewId: \(.reviewId)\n" else "" end) +
        (if .userId then "userId: \(.userId)\n" else "" end) +
        (if .gameId then "gameId: \(.gameId)\n" else "" end) +
        (if .note!=null then "note: \(.note)\n" else "" end) +
        (if .description then "desc: \(.description)\n" else "" end) +
        (if .submittedAt then "submittedAt: \(.submittedAt)\n" else "" end)
      '
    fi
  else
    print_json "$resp"
  fi
  pause
}

feedback_get_incidents() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local gameId severity page size
  gameId="$(prompt "GameId" "G300")"
  severity="$(prompt "Sévérité (HAUTE/NORMALE/BASSE/CRITIQUE)" "HAUTE")"; severity="${severity^^}"
  page="$(prompt "Page" "0")"
  size="$(prompt "Taille (size)" "20")"

  local qs="gameId=$(urlencode "$gameId")&page=$(urlencode "$page")&size=$(urlencode "$size")"
  [[ -n "${severity// }" ]] && qs="${qs}&severity=$(urlencode "$severity")"

  local url="${PLATFORM_URL}/platform/feedback/incidents?${qs}"
  set +e
  local resp
  resp="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi

  if command -v jq >/dev/null 2>&1; then
    echo ""
    echo "$resp" | jq -r '"TotalElements: \(.totalElements) | TotalPages: \(.totalPages) | Page: \(.number)"'
    local c
    c="$(echo "$resp" | jq '.content | length')"
    if [[ "$c" == "0" ]]; then
      echo "Aucun incident."
    else
      echo "$resp" | jq -r '.content[] |
        "----------------------\n" +
        (if .incidentId then "incidentId: \(.incidentId)\n" else "" end) +
        (if .userId then "userId: \(.userId)\n" else "" end) +
        (if .gameId then "gameId: \(.gameId)\n" else "" end) +
        (if .severity then "severity: \(.severity)\n" else "" end) +
        (if .description then "desc: \(.description)\n" else "" end) +
        (if .environment then "env: \(.environment)\n" else "" end) +
        (if .reportedAt then "reportedAt: \(.reportedAt)\n" else "" end)
      '
    fi
  else
    print_json "$resp"
  fi
  pause
}

feedback_review_stats() {
  [[ "$CURRENT_ROLE" == "NONE" ]] && echo "Veuillez d'abord vous connecter." && pause && return
  local gameId
  gameId="$(prompt "GameId" "G300")"

  local url="${PLATFORM_URL}/platform/feedback/reviews/$(urlencode "$gameId")/stats"
  set +e
  local resp
  resp="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then show_http_error "$rc"; echo "$resp"; pause; return; fi
  print_json "$resp"
  pause
}

# -------------------------
# Menu
# -------------------------
menu() {
  if [[ "$CURRENT_ROLE" == "NONE" ]]; then
    echo "1) Créer un utilisateur (User)"
    echo "2) Créer un éditeur (Redactor)"
    echo "3) Connexion"
    echo "0) Quitter"
    return
  fi

  echo "1) Suivre un utilisateur"
  echo "2) Afficher les abonnements (Users)"
  echo "3) Suivre un éditeur"
  echo "4) Afficher les éditeurs suivis"
  echo "5) Voir les jeux d'un éditeur suivi"

  echo "------ Store / Catalogue ------"
  echo "6) Lister/Rechercher jeux du catalogue"
  echo "7) Détails d'un jeu (catalogue)"

  echo "------ Achats / Bibliothèque ------"
  echo "8) Acheter un jeu"
  echo "9) Voir ma bibliothèque"
  echo "10) Acheter un DLC"
  echo "11) Voir mes DLC"
  echo "12) Vérifier possession d'un jeu"
  echo "13) Voir nb ventes d'un jeu"

  echo "------ Reviews ------"
  echo "14) Déposer un avis"
  echo "15) Voter utile/inutile sur un avis"
  echo "16) Lister avis d'un jeu"
  echo "17) Lister avis d'un utilisateur"

  echo "------ Incidents ------"
  echo "18) Signaler un incident"
  echo "19) Lister incidents d'un jeu"
  echo "20) Compter incidents d'un jeu"

  echo "------ Notifications ------"
  echo "21) Voir mes notifications"
  echo "21b) Créer une notif test"

  if [[ "$CURRENT_ROLE" == "REDACTOR" ]]; then
    echo "------ Publisher (Éditeur) ------"
    echo "22) Publier un jeu"
    echo "23) Mes jeux"
    echo "24) Publier un patch"
    echo "25) Lister patchs d'un jeu"
    echo "26) Publier un DLC"
    echo "27) Lister DLC d'un jeu"
    echo "28) Déconnexion"
  else
    echo "22) Déconnexion"
  fi

  echo "------ Gameplay ------"
  echo "30) Démarrer une session de jeu"
  echo "31) Terminer une session de jeu"
  echo "32) Consulter mon temps de jeu"

  echo "------ Feedback (agrégé) ------"
  echo "33) Voir reviews d'un jeu (paginé)"
  echo "34) Voir incidents d'un jeu (paginé)"
  echo "35) Stats reviews d'un jeu"

  echo "0) Quitter"
}

# -------------------------
# Main loop
# -------------------------
while true; do
  banner
  menu
  read -r -p "Choix: " c

  if [[ "$CURRENT_ROLE" == "NONE" ]]; then
    case "$c" in
      1) action_register_user ;;
      2) action_register_redactor ;;
      3) connexion ;;
      0) break ;;
      *) echo "Choix invalide"; pause ;;
    esac
    continue
  fi

  case "$c" in
    1) follow_user ;;
    2) show_following ;;
    3) follow_redactor ;;
    4) show_followed_redactors ;;
    5) show_games_of_followed_editor ;;

    6) catalog_list_games ;;
    7) catalog_game_details ;;

    8) buy_game ;;
    9) my_library ;;
    10) buy_dlc ;;
    11) my_dlcs ;;
    12) check_ownership ;;
    13) game_sales_count ;;

    14) submit_review ;;
    15) rate_review_helpful ;;
    16) list_reviews_by_game ;;
    17) list_reviews_by_user ;;

    18) report_incident ;;
    19) list_incidents_by_game ;;
    20) count_incidents_by_game ;;

    21) my_notifications ;;
    21b) create_notification_test ;;

    30) start_game_session ;;
    31) end_game_session ;;
    32) my_playtime ;;

    33) feedback_get_reviews ;;
    34) feedback_get_incidents ;;
    35) feedback_review_stats ;;
    0) break ;;

    22)
      if [[ "$CURRENT_ROLE" == "REDACTOR" ]]; then
        publish_game
      else
        deconnexion
      fi
      ;;
    23) [[ "$CURRENT_ROLE" == "REDACTOR" ]] && my_games || { echo "Choix invalide"; pause; } ;;
    24) [[ "$CURRENT_ROLE" == "REDACTOR" ]] && publish_patch || { echo "Choix invalide"; pause; } ;;
    25) [[ "$CURRENT_ROLE" == "REDACTOR" ]] && list_patches_for_game || { echo "Choix invalide"; pause; } ;;
    26) [[ "$CURRENT_ROLE" == "REDACTOR" ]] && publish_dlc || { echo "Choix invalide"; pause; } ;;
    27) [[ "$CURRENT_ROLE" == "REDACTOR" ]] && list_dlcs_for_game_publisher || { echo "Choix invalide"; pause; } ;;
    28) [[ "$CURRENT_ROLE" == "REDACTOR" ]] && deconnexion || { echo "Choix invalide"; pause; } ;;

    *) echo "Choix invalide"; pause ;;
  esac
done