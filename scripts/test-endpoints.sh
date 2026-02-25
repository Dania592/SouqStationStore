#!/usr/bin/env bash

# test-endpoints.sh
# Ce script exécute une série de requêtes cURL pour tester l'ensemble du workflow de SouqStationStore.

PLATFORM_URL="http://localhost:8081"
PUBLISHER_URL="http://localhost:8082"

echo "========================================="
echo "        Début des tests d'intégration    "
echo "========================================="

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

# Wait a bit for Kafka event processing
sleep 2

echo -e "\n[5] U100 (JeanD) suit U200 (MartinA)..."
curl -s -X POST "$PLATFORM_URL/platform/users/follow" \
    -d "userId=U100" \
    -d "followedId=U200" | jq .

echo -e "\n[6] U100 achète le jeu G300..."
curl -s -X POST "$PLATFORM_URL/platform/purchases/game" \
    -d "userId=U100" \
    -d "gameId=G300" | jq .

echo -e "\n[7] U100 consulte sa bibliothèque de jeux..."
curl -s "$PLATFORM_URL/platform/purchases/library?userId=U100" | jq .

echo -e "\n[8] U100 dépose un avis sur G300..."
REVIEW_RESPONSE=$(curl -s -X POST "$PLATFORM_URL/platform/reviews/submit" \
    -d "userId=U100" \
    -d "gameId=G300" \
    -d "note=9" \
    -d "description=Incroyable !")
echo $REVIEW_RESPONSE | jq .

# Extract the reviewId safely from the JSON response
REVIEW_ID=$(echo $REVIEW_RESPONSE | jq -r '.reviewId // empty')

if [ -n "$REVIEW_ID" ] && [ "$REVIEW_ID" != "null" ]; then
    echo -e "\n[9] U200 évalue l'avis de U100 (utile=true)..."
    curl -s -X POST "$PLATFORM_URL/platform/reviews/$REVIEW_ID/rate" \
        -d "userId=U200" \
        -d "isHelpful=true" | jq .
else
    echo -e "\n[9] Impossible de noter l'avis (Review ID introuvable). L'événement de test précédent a pu échouer."
fi

echo -e "\n[10] U100 signale un incident sur G300..."
curl -s -X POST "$PLATFORM_URL/platform/incidents/report" \
    -d "userId=U100" \
    -d "gameId=G300" \
    -d "severity=HAUTE" \
    -d "description=Crashs intempestifs" \
    -d "environment=Windows 11" | jq .

echo -e "\n[11] L'éditeur R200 publie un patch pour G300..."
curl -s -X POST "$PUBLISHER_URL/publisher/publish-patch" \
    -d "gameId=G300" \
    -d "targetVersion=1.0.1" \
    --data-urlencode "patchNotes=Correction du crash sous Windows 11" \
    -d "releasedAt=2025-11-20" \
    --data-urlencode "modifications=CORRECTION" \
    --data-urlencode "modifications=OPTIMISATION" | jq .

# Wait a bit for Kafka event processing
sleep 2

echo -e "\n[12] Vérification finale du catalogue (Jeu G300) côté plateforme..."
curl -s "$PLATFORM_URL/platform/catalog/games/G300" | jq .

echo -e "\n========================================="
echo "        Fin des tests d'intégration      "
echo "========================================="
