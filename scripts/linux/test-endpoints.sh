#!/usr/bin/env bash
# test-endpoints-full.seed.sh (Linux / bash)
# "Seeder" d'intégration : crée beaucoup d'utilisateurs/éditeurs/jeux + follows + achats + sessions + reviews + incidents + patches + notifs
# Prérequis: curl (jq recommandé)

set -euo pipefail

# =========================
# Config
# =========================
: "${PLATFORM_URL:=http://localhost:8081}"
: "${PUBLISHER_URL:=http://localhost:8082}"
: "${NOTIF_URL:=http://localhost:8083}" # optionnel

command -v curl >/dev/null 2>&1 || { echo "curl requis"; exit 1; }
HAVE_JQ=0
command -v jq >/dev/null 2>&1 && HAVE_JQ=1

# =========================
# Tunables (volume de données)
# =========================
NB_USERS=12
NB_REDACTORS=3
NB_GAMES=10
NB_FOLLOWS=18
NB_PURCHASES=20
NB_SESSIONS=20
NB_REVIEWS=25
NB_INCIDENTS=12
NB_PATCHES=12
SEND_NOTIFS=1

BASE_GAME_ID=300

GENRES=("RPG" "ACTION" "STRATEGY")
PLATFORMS=("PC" "SWITCH" "WEB")
SEVERITIES=("BASSE" "NORMALE" "HAUTE" "CRITIQUE")
MODS_POOL=("CORRECTION" "OPTIMISATION" "AJOUT" "SECURITE" "PERF" "UX")

# =========================
# Utils
# =========================
json_pretty() {
  if [[ "$HAVE_JQ" -eq 1 ]]; then jq .; else cat; fi
}

# URL encode via python3 if possible (recommended)
urlencode() {
  local s="${1:-}"
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY' "$s"
import sys, urllib.parse
print(urllib.parse.quote_plus(sys.argv[1]))
PY
  else
    # fallback minimal
    echo "$s"
  fi
}

# GET helper (returns body)
http_get() {
  local url="$1"
  curl -sS -f "$url"
}

# POST form helper with key/value pairs (auto-encode)
# usage: http_post_kv URL key val key val ...
http_post_kv() {
  local url="$1"; shift
  local args=()
  while (( "$#" )); do
    local k="$1"; local v="${2:-}"; shift 2
    args+=( --data-urlencode "${k}=${v}" )
  done
  curl -sS -f -X POST "$url" -H "Content-Type: application/x-www-form-urlencoded" "${args[@]}"
}

# POST multi helper: base kv + repeated multi key values
# usage:
#   http_post_multi URL key val ... --multi modifications "A,B,C"
http_post_multi() {
  local url="$1"; shift
  local args=()

  while (( "$#" )); do
    if [[ "$1" == "--multi" ]]; then shift; break; fi
    local k="$1"; local v="${2:-}"; shift 2
    args+=( --data-urlencode "${k}=${v}" )
  done

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

safe_post_kv() {
  local label="$1"; shift
  local url="$1"; shift
  echo -e "\n${label}"
  set +e
  local out
  out="$(http_post_kv "$url" "$@" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then
    echo "POST failed: $url"
    echo "$out"
    return 1
  fi
  echo "$out" | json_pretty
  return 0
}

safe_post_multi() {
  local label="$1"; shift
  local url="$1"; shift
  echo -e "\n${label}"
  set +e
  local out
  out="$(http_post_multi "$url" "$@" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then
    echo "POST failed: $url"
    echo "$out"
    return 1
  fi
  echo "$out" | json_pretty
  return 0
}

try_get() {
  local label="$1"
  local url="$2"
  echo -e "\n${label}"
  set +e
  local out
  out="$(http_get "$url" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )); then
    echo "GET failed: $url"
    echo "$out"
    return 0
  fi
  echo "$out" | json_pretty
}

sleep_ms() {
  local ms="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<PY "$ms"
import time, sys
time.sleep(int(sys.argv[1])/1000)
PY
  else
    # approx
    sleep 0.2
  fi
}

rand_int() {
  local max="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY' "$max"
import random, sys
print(random.randrange(int(sys.argv[1])))
PY
  else
    echo $((RANDOM % max))
  fi
}

rand_pick() {
  # usage: rand_pick array_name
  local arr_name="$1"
  # shellcheck disable=SC1083,SC2086
  eval "local n=\${#${arr_name}[@]}"
  local idx; idx="$(rand_int "$n")"
  # shellcheck disable=SC1083,SC2086
  eval "echo \${${arr_name}[$idx]}"
}

# Extract JSON field with jq if possible (else empty)
json_field() {
  local json="$1"
  local jq_expr="$2"
  if [[ "$HAVE_JQ" -eq 1 ]]; then
    echo "$json" | jq -r "$jq_expr" 2>/dev/null || true
  else
    echo ""
  fi
}

# =========================
# Banner
# =========================
echo "========================================="
echo "   SouqStationStore - Full Integration   "
echo "           LINUX DATA SEEDER            "
echo "========================================="
echo "PLATFORM_URL=$PLATFORM_URL"
echo "PUBLISHER_URL=$PUBLISHER_URL"
echo "NOTIF_URL=$NOTIF_URL (optional)"
echo "-----------------------------------------"

# =========================
# Lists for seeded IDs
# =========================
USER_IDS=("U100" "U200")
REDACTOR_IDS=("R200")
GAME_IDS=("G300")
REVIEW_IDS=()

# =========================
# 1) Baseline users/redactor (comme ton PS)
# =========================
safe_post_kv "[1] Création de l'utilisateur U100..." \
  "$PLATFORM_URL/platform/register-user" \
  userId "U100" name "Dupont" email "dupont@test.com" displayName "JeanD" birth "1990-05-12" solde "100.5" || true

safe_post_kv "[2] Création de l'utilisateur U200..." \
  "$PLATFORM_URL/platform/register-user" \
  userId "U200" name "Martin" email "martin.acheteur@test.com" displayName "MartinA" birth "1992-06-15" solde "50.0" || true

safe_post_kv "[3] Création de l'éditeur R200..." \
  "$PLATFORM_URL/platform/register-redactor" \
  userId "R200" name "Martin" email "martin@test.com" displayName "MarcM" birth "1985-08-20" solde "250.75" individual "true" || true

# =========================
# 2) More users & redactors
# =========================
echo -e "\n[1b] Création de $NB_USERS utilisateurs supplémentaires..."
for i in $(seq 1 "$NB_USERS"); do
  id="U$((300+i))"
  USER_IDS+=("$id")
  solde="25.0"
  if (( i % 3 == 0 )); then solde="0.0"; elif (( i % 3 == 2 )); then solde="120.0"; fi
  birth=$(printf "199%d-%02d-%02d" $((i%10)) $(((i%9)+1)) $(((i%9)+1)))
  safe_post_kv "[U] register $id" \
    "$PLATFORM_URL/platform/register-user" \
    userId "$id" name "User$i" email "user${i}@test.com" displayName "Player$i" birth "$birth" solde "$solde" || true
  sleep_ms 120
done

echo -e "\n[1c] Création de $NB_REDACTORS éditeurs supplémentaires..."
for i in $(seq 1 "$NB_REDACTORS"); do
  rid="R$((300+i))"
  REDACTOR_IDS+=("$rid")
  birth=$(printf "198%d-%02d-%02d" $((i%10)) $(((i%9)+1)) $(((i%9)+2)))
  safe_post_kv "[R] register $rid" \
    "$PLATFORM_URL/platform/register-redactor" \
    userId "$rid" name "Redactor$i" email "redactor${i}@test.com" displayName "Studio$i" birth "$birth" solde "500.0" individual "true" || true
  sleep_ms 120
done

# =========================
# 3) Publish games
# =========================
safe_post_kv "[4] Publication du jeu G300 par R200..." \
  "$PUBLISHER_URL/publisher/publish-game" \
  gameId "G300" title "The Witcher 3" description "Open world RPG" platform "PC" genre "RPG" \
  idEditeur "R200" version "1.0" prixInit "39.99" releaseDate "2025-10-10" || true

echo -e "\n[4b] Publication de $NB_GAMES jeux supplémentaires..."
for i in $(seq 1 "$NB_GAMES"); do
  gid="G$((BASE_GAME_ID+i))"
  GAME_IDS+=("$gid")
  pub="${REDACTOR_IDS[$(((i-1) % ${#REDACTOR_IDS[@]}))]}"
  genre="${GENRES[$(((i-1) % ${#GENRES[@]}))]}"
  plat="${PLATFORMS[$(((i-1) % ${#PLATFORMS[@]}))]}"
  price="$((19 + (i % 4)*10)).99"
  release=$(printf "2025-%02d-%02d" $(((i%12)+1)) $(((i%25)+1)))
  promoTag=""
  if (( i % 4 == 0 )); then promoTag=" [PROMOTION]"; fi
  safe_post_kv "[G] publish $gid by $pub" \
    "$PUBLISHER_URL/publisher/publish-game" \
    gameId "$gid" title "Game $i" description "Seeded description $i$promoTag" platform "$plat" genre "$genre" \
    idEditeur "$pub" version "1.$i.0" prixInit "$price" releaseDate "$release" || true
  sleep_ms 150
done

try_get "[4c] (OPTIONNEL) Count games by publisher (R200)..." \
  "$PUBLISHER_URL/publisher/games/count?idEditeur=$(urlencode "R200")"

sleep 1

# =========================
# 4) Social follows
# =========================
echo -e "\n[5] Social: création de $NB_FOLLOWS follows aléatoires..."
for i in $(seq 1 "$NB_FOLLOWS"); do
  a="$(rand_pick USER_IDS)"
  b="$(rand_pick USER_IDS)"
  [[ "$a" == "$b" ]] && continue

  safe_post_kv "[F] $a suit $b" \
    "$PLATFORM_URL/platform/users/follow" \
    userId "$a" followedId "$b" || true

  if (( i % 3 == 0 )); then
    r="$(rand_pick REDACTOR_IDS)"
    # endpoint peut ne pas exister -> best effort
    safe_post_kv "[F] $a suit l'éditeur $r" \
      "$PLATFORM_URL/platform/users/follow-redactor" \
      userId "$a" redactorId "$r" || true
  fi
  sleep_ms 120
done

try_get "[5b] (OPTIONNEL) Liste éditeurs suivis par U100..." \
  "$PLATFORM_URL/platform/users/following-redactors?userId=$(urlencode "U100")"

# =========================
# 5) Purchases
# =========================
echo -e "\n[6] Achats: création de $NB_PURCHASES achats (user x game)..."
for i in $(seq 1 "$NB_PURCHASES"); do
  u="$(rand_pick USER_IDS)"
  g="$(rand_pick GAME_IDS)"
  safe_post_kv "[BUY] $u achète $g" \
    "$PLATFORM_URL/platform/purchases/game" \
    userId "$u" gameId "$g" || true
  sleep_ms 120
done

try_get "[7] Bibliothèque de U100..." \
  "$PLATFORM_URL/platform/purchases/library?userId=$(urlencode "U100")"
try_get "[7c] (OPTIONNEL) Sales count G300..." \
  "$PLATFORM_URL/platform/purchases/sales-count?gameId=$(urlencode "G300")"

# =========================
# 6) Sessions (start/end, wait 3s)
# =========================
echo -e "\n[8] Gameplay sessions: création de $NB_SESSIONS sessions..."
for i in $(seq 1 "$NB_SESSIONS"); do
  u="$(rand_pick USER_IDS)"
  g="$(rand_pick GAME_IDS)"
  safe_post_kv "[S] start $u->$g" \
    "$PLATFORM_URL/platform/sessions/start" \
    userId "$u" gameId "$g" || true
  sleep 3
  safe_post_kv "[S] end   $u->$g" \
    "$PLATFORM_URL/platform/sessions/end" \
    userId "$u" gameId "$g" || true
done

try_get "[10] Temps de jeu U100 (tous jeux)..." \
  "$PLATFORM_URL/platform/sessions/users/$(urlencode "U100")/playtime"

# =========================
# 7) Reviews + helpful votes
# =========================
echo -e "\n[12] Reviews: création de $NB_REVIEWS avis..."
for i in $(seq 1 "$NB_REVIEWS"); do
  u="$(rand_pick USER_IDS)"
  g="$(rand_pick GAME_IDS)"
  note=$(( (RANDOM % 8) + 3 ))  # 3..10
  desc="Seed review $i ($u -> $g) note=$note"

  set +e
  rev="$(http_post_kv "$PLATFORM_URL/platform/reviews/submit" userId "$u" gameId "$g" note "$note" description "$desc" 2>&1)"
  rc=$?
  set -e
  if (( rc == 0 )); then
    echo "$rev" | json_pretty
    rid="$(json_field "$rev" '.reviewId // empty')"
    [[ -n "$rid" ]] && REVIEW_IDS+=("$rid")
  else
    echo "review submit failed ($u,$g)"
    echo "$rev"
  fi

  # helpful vote 1/2 du temps
  if (( i % 2 == 0 )) && ((${#REVIEW_IDS[@]} > 0)); then
    voter="$(rand_pick USER_IDS)"
    rid="${REVIEW_IDS[$(rand_int ${#REVIEW_IDS[@]})]}"
    safe_post_kv "[VOTE] $voter vote utile sur $rid" \
      "$PLATFORM_URL/platform/reviews/$(urlencode "$rid")/rate" \
      userId "$voter" isHelpful "true" || true
  fi
  sleep_ms 120
done

try_get "[15] Feedback reviews (paginé) G300..." \
  "$PLATFORM_URL/platform/feedback/reviews?gameId=$(urlencode "G300")&minNote=0&sort=desc&page=0&size=20"
try_get "[17] Stats reviews G300..." \
  "$PLATFORM_URL/platform/feedback/reviews/$(urlencode "G300")/stats"

# =========================
# 8) Incidents
# =========================
echo -e "\n[14] Incidents: création de $NB_INCIDENTS incidents..."
for i in $(seq 1 "$NB_INCIDENTS"); do
  u="$(rand_pick USER_IDS)"
  g="$(rand_pick GAME_IDS)"
  sev="${SEVERITIES[$(((i-1) % ${#SEVERITIES[@]}))]}"
  envt="Ubuntu 22.04"
  if (( i % 2 == 0 )); then envt="Windows 11"; fi
  desc="Seed incident $i ($sev) on $g by $u"

  safe_post_kv "[INC] $u -> $g ($sev)" \
    "$PLATFORM_URL/platform/incidents/report" \
    userId "$u" gameId "$g" severity "$sev" description "$desc" environment "$envt" || true
  sleep_ms 150
done

try_get "[16] Feedback incidents (paginé) G300 (severity=HAUTE)..." \
  "$PLATFORM_URL/platform/feedback/incidents?gameId=$(urlencode "G300")&severity=HAUTE&page=0&size=20"

# =========================
# 9) Patches (multi modifications)
# =========================
echo -e "\n[18] Patches: création de $NB_PATCHES patches..."
for i in $(seq 1 "$NB_PATCHES"); do
  g="$(rand_pick GAME_IDS)"
  m1="$(rand_pick MODS_POOL)"
  m2="$(rand_pick MODS_POOL)"
  # unique-ish
  if [[ "$m2" == "$m1" ]]; then m2="OPTIMISATION"; fi
  mods="${m1},${m2}"
  rel=$(printf "2025-11-%02d" $(((i%28)+1)))

  safe_post_multi "[PATCH] $g -> 1.0.$i" \
    "$PUBLISHER_URL/publisher/publish-patch" \
    gameId "$g" targetVersion "1.0.$i" patchNotes "Seed patch $i for $g" releasedAt "$rel" \
    --multi modifications "$mods" || true
  sleep_ms 120
done

# =========================
# 10) Final catalog checks
# =========================
try_get "[19] Vérification finale du catalogue G300..." \
  "$PLATFORM_URL/platform/catalog/games/$(urlencode "G300")"

for _ in 1 2 3; do
  g="$(rand_pick GAME_IDS)"
  try_get "[19b] Détails catalogue $g ..." \
    "$PLATFORM_URL/platform/catalog/games/$(urlencode "$g")"
done

try_get "[19c] Liste catalogue (sans filtre)..." \
  "$PLATFORM_URL/platform/catalog/games"

# =========================
# 11) Optional Notifications
# =========================
if (( SEND_NOTIFS == 1 )); then
  echo -e "\n[20] Notifications: envoi de quelques notifs (best effort)..."
  for u in "U100" "U200" "${USER_IDS[@]:0:3}"; do
    # service peut être absent -> best effort
    safe_post_kv "[NOTIF] send -> $u" \
      "$NOTIF_URL/notifications/send" \
      userId "$u" type "TEST_NOTIF" message "Seed notif for $u at $(date -Iseconds)" || true
  done

  try_get "[21] (OPTIONNEL) Lecture des notifications de U100..." \
    "$NOTIF_URL/notifications/$(urlencode "U100")"
fi

echo "========================================="
echo "   Fin des tests d'intégration (seed)    "
echo "========================================="