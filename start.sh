#!/usr/bin/env bash
set -e

echo "========================================="
echo "   Démarrage Rapide - SouqStationStore   "
echo "========================================="

echo -e "\n[1/4] Démarrage de l'infrastructure (Docker)..."
cd infrastructure/docker
docker compose up -d
cd ../..

echo -e "\nAttente de l'initialisation de Kafka et de la Base de Données (15s)..."
sleep 15

echo -e "\n[2/4] Création des topics Kafka..."
if command -v bash >/dev/null 2>&1; then
    bash ./scripts/linux/setup-kafka-topics.sh
else
    echo "Avertissement : bash introuvable, impossible de lancer ./scripts/linux/setup-kafka-topics.sh automatiquement."
fi

echo -e "\n[3/4] Démarrage des Microservices"
echo "=================================================================================="
echo "  ACTION REQUISE DE VOTRE PART :"
echo "  Veuillez démarrer les 3 services suivants depuis votre IDE (ex: IntelliJ) :"
echo "    1. PlatformServiceApplication     (Port 8081)"
echo "    2. PublisherServiceApplication    (Port 8082)"
echo "    3. NotificationServiceApplication (Port 8083)"
echo "=================================================================================="
read -p "Appuyez sur Entrée UNE FOIS QUE LES 3 SERVICES SONT DÉMARRÉS ET PRÊTS..."

echo -e "\n[4/4] Peuplement de la base de données (test-endpoints)..."
if command -v bash >/dev/null 2>&1; then
    bash ./scripts/linux/test-endpoints.sh
else
    echo "Avertissement : bash introuvable, impossible d'exécuter ./scripts/linux/test-endpoints.sh."
fi

echo -e "\n========================================="
echo "   ENVIRONNEMENT PRÊT ET PEUPLÉ !        "
echo "========================================="
echo "WORKFLOW POUR INTERAGIR AVEC LE PROJET :"
echo ""
echo "1. Lancer le CLI interactif :"
echo "   > bash ./scripts/linux/cli/souq-interactive.sh"
echo "   (ou pwsh ./scripts/windows/cli/souq-interactive.ps1 si vous préférez sur Windows)"
echo ""
echo "2. Dans le menu du CLI, tester les rôles :"
echo "   - Option [0] : Connectez-vous avec 'dupont@test.com' (Acheteur de base)."
echo "   - Option [0] : Connectez-vous avec 'martin@test.com' (Éditeur)."
echo ""
echo "3. Essayez les fonctionnalités :"
echo "   - En tant qu'acheteur : Acheter un jeu [10], Voir sa bibliothèque [11], Laisser un avis [16]"
echo "   - En tant qu'éditeur : Publier un jeu [8], Publier un DLC [23], Publier un Patch [20]"
echo ""
echo "Amusez-vous bien !"
