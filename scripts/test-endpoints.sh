#!/usr/bin/env bash
set -euo pipefail

# =========================
# Config
# =========================
PLATFORM_URL="${PLATFORM_URL:-http://localhost:8081}"
PUBLISHER_URL="${PUBLISHER_URL:-http://localhost:8082}"
NOTIF_URL="${NOTIF_URL:-http://localhost:8083}"  # optionnel

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }; }
require curl
require jq

echo "========================================="
echo "   SouqStationStore - Full Integration   "
echo "========================================="
echo "PLATFORM_URL=$PLATFORM_URL"
echo "PUBLISHER_URL=$PUBLISHER_URL"
echo "NOTIF_URL=$NOTIF_URL (optional)"
echo "-----------------------------------------"

# =========================
# 1) Create users & redactor
# =========================
echo -e "\n[1] Création de l'utilisateur U100 (Acheteur)..."
curl -s -X POST "$PLATFORM_URL/platform/register-user" \
  -d "userId=U100" \
  -d "name=Dupont" \
  -d "email=dupont@test.com" \
  -d "displayName=JeanD" \
  -d "birth=1990-05-12" \
  -d "solde=100.5" | jq .

echo -e "\n[2] Création de l'utilisateur U200 (Acheteur)..."
curl -s -X POST "$PLATFORM_URL/platform/register-user" \
  -d "userId=U200" \
  -d "name=Martin" \
  -d "email=martin.acheteur@test.com" \
  -d "displayName=MartinA" \
  -d "birth=1992-06-15" \
  -d "solde=0.0" | jq .

echo -e "\n[3] Création de l'éditeur R200..."
curl -s -X POST "$PLATFORM_URL/platform/register-redactor" \
  -d "userId=R200" \
  -d "name=Martin" \
  -d "email=martin@test.com" \
  -d "displayName=MarcM" \
  -d "birth=1985-08-20" \
  -d "solde=250.75" \
  -d "individual=true" | jq .

# =========================
# 2) Publish game
# =========================
echo -e "\n[4] Publication du jeu G300 par l'éditeur R200..."
curl -s -X POST "$PUBLISHER_URL/publisher/publish-game" \
  --data-urlencode "gameId=G300" \
  --data-urlencode "title=The Witcher 3" \
  --data-urlencode "description=Open world RPG" \
  --data-urlencode "platform=PC" \
  --data-urlencode "genre=RPG" \
  --data-urlencode "idEditeur=R200" \
  --data-urlencode "version=1.0" \
  --data-urlencode "prixInit=39.99" \
  --data-urlencode "releaseDate=2025-10-10" | jq .

echo -e "\n[4b] (OPTIONNEL) Count games by publisher (publisher-service)..."
curl -s "$PUBLISHER_URL/publisher/games/count?idEditeur=R200" | jq . || true

# Wait for async propagation (Kafka)
sleep 2

# =========================
# 3) Social
# =========================
echo -e "\n[5] U100 suit U200..."
curl -s -X POST "$PLATFORM_URL/platform/users/follow" \
  -d "userId=U100" \
  -d "followedId=U200" | jq .

echo -e "\n[5b] (OPTIONNEL) U100 suit l'éditeur R200..."
curl -s -X POST "$PLATFORM_URL/platform/users/follow-redactor" \
  -d "userId=U100" \
  -d "redactorId=R200" | jq . || true

echo -e "\n[5c] (OPTIONNEL) Liste des éditeurs suivis par U100..."
curl -s "$PLATFORM_URL/platform/users/following-redactors?userId=U100" | jq . || true

echo -e "\n[5d] (OPTIONNEL) Jeux par éditeur R200 (publisher-service)..."
curl -s "$PUBLISHER_URL/publisher/games/by-publisher?idEditeur=R200" | jq . || true

# =========================
# 4) Purchases / Library
# =========================
echo -e "\n[6] U100 achète le jeu G300..."
curl -s -X POST "$PLATFORM_URL/platform/purchases/game" \
  -d "userId=U100" \
  -d "gameId=G300" | jq .

echo -e "\n[7] U100 consulte sa bibliothèque..."
curl -s "$PLATFORM_URL/platform/purchases/library?userId=U100" | jq .

echo -e "\n[7b] (OPTIONNEL) Vérifier possession U100 -> G300..."
curl -s "$PLATFORM_URL/platform/purchases/owns?userId=U100&gameId=G300" | jq . || true

echo -e "\n[7c] (OPTIONNEL) Sales count pour G300..."
curl -s "$PLATFORM_URL/platform/purchases/sales-count?gameId=G300" | jq . || true

# =========================
# 5) Gameplay sessions (NEW)
# =========================
echo -e "\n[8] U100 démarre une session de jeu G300..."
curl -s -X POST "$PLATFORM_URL/platform/sessions/start" \
  -d "userId=U100" \
  -d "gameId=G300" | jq .

sleep 180

echo -e "\n[9] U100 termine la session de jeu G300..."
curl -s -X POST "$PLATFORM_URL/platform/sessions/end" \
  -d "userId=U100" \
  -d "gameId=G300" | jq .

echo -e "\n[10] Temps de jeu total de U100 (tous jeux)..."
curl -s "$PLATFORM_URL/platform/sessions/users/U100/playtime" | jq .

echo -e "\n[11] Temps de jeu de U100 sur G300..."
curl -s "$PLATFORM_URL/platform/sessions/users/U100/playtime?gameId=G300" | jq .

# =========================
# 6) Reviews
# =========================
echo -e "\n[12] U100 dépose un avis sur G300..."
REVIEW_RESPONSE=$(curl -s -X POST "$PLATFORM_URL/platform/reviews/submit" \
  -d "userId=U100" \
  -d "gameId=G300" \
  -d "note=9" \
  -d "description=Incroyable !")
echo "$REVIEW_RESPONSE" | jq .

REVIEW_ID=$(echo "$REVIEW_RESPONSE" | jq -r '.reviewId // empty')

echo -e "\n[13] (OPTIONNEL) U200 vote utile sur l'avis de U100..."
if [[ -n "${REVIEW_ID:-}" && "$REVIEW_ID" != "null" ]]; then
  curl -s -X POST "$PLATFORM_URL/platform/reviews/$REVIEW_ID/rate" \
    -d "userId=U200" \
    -d "isHelpful=true" | jq .
else
  echo "ReviewId introuvable, skip."
fi

# =========================
# 7) Incidents
# =========================
echo -e "\n[14] U100 signale un incident sur G300..."
curl -s -X POST "$PLATFORM_URL/platform/incidents/report" \
  -d "userId=U100" \
  -d "gameId=G300" \
  -d "severity=HAUTE" \
  -d "description=Crashs intempestifs" \
  -d "environment=Windows 11" | jq .

# =========================
# 8) Feedback aggregation (NEW)
# =========================
echo -e "\n[15] Feedback reviews (paginé) pour G300 (minNote=0, sort=desc, page=0, size=20)..."
curl -s "$PLATFORM_URL/platform/feedback/reviews?gameId=G300&minNote=0&sort=desc&page=0&size=20" | jq .

echo -e "\n[16] Feedback incidents (paginé) pour G300 (severity=HAUTE)..."
curl -s "$PLATFORM_URL/platform/feedback/incidents?gameId=G300&severity=HAUTE&page=0&size=20" | jq .

echo -e "\n[17] Stats reviews pour G300..."
curl -s "$PLATFORM_URL/platform/feedback/reviews/G300/stats" | jq .

# =========================
# 9) Publish patch
# =========================
echo -e "\n[18] L'éditeur R200 publie un patch pour G300..."
curl -s -X POST "$PUBLISHER_URL/publisher/publish-patch" \
  -d "gameId=G300" \
  -d "targetVersion=1.0.1" \
  --data-urlencode "patchNotes=Correction du crash sous Windows 11" \
  -d "releasedAt=2025-11-20" \
  --data-urlencode "modifications=CORRECTION" \
  --data-urlencode "modifications=OPTIMISATION" | jq .

sleep 2

# =========================
# 10) Final catalog check
# =========================
echo -e "\n[19] Vérification finale du catalogue (Jeu G300) côté plateforme..."
curl -s "$PLATFORM_URL/platform/catalog/games/G300" | jq .

# =========================
# OPTIONAL: Notifications / DLC (if available)
# =========================
echo -e "\n[20] (OPTIONNEL) Notifications de U100..."
curl -s "$NOTIF_URL/notifications/U100" | jq . || true

echo -e "\n========================================="
echo "        Fin des tests d'intégration      "
echo "========================================="