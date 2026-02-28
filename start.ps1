$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host "   Démarrage Rapide - SouqStationStore   "
Write-Host "========================================="

Write-Host "`n[1/4] Nettoyage et démarrage de l'infrastructure (Docker)..."
Push-Location "infrastructure/docker"
try {
    Write-Host "Arrêt de l'infrastructure existante et suppression des volumes..."
    docker compose down -v
    Write-Host "Démarrage des conteneurs..."
    docker compose up -d
} finally {
    Pop-Location
}

Write-Host "`nAttente de l'initialisation de Kafka et de la Base de Données (15s)..."
Start-Sleep -Seconds 15

Write-Host "`n[2/4] Création des topics Kafka..."
if (Get-Command pwsh -ErrorAction SilentlyContinue) {
    pwsh ./scripts/windows/setup-kafka-topics.ps1
} else {
    powershell ./scripts/windows/setup-kafka-topics.ps1
}

Write-Host "`n[3/4] Démarrage des Microservices"
Write-Host "=================================================================================="
Write-Host "  ACTION REQUISE DE VOTRE PART :"
Write-Host "  Veuillez démarrer les 3 services suivants depuis votre IDE (ex: IntelliJ) :"
Write-Host "    1. PlatformServiceApplication     (Port 8081)"
Write-Host "    2. PublisherServiceApplication    (Port 8082)"
Write-Host "    3. NotificationServiceApplication (Port 8083)"
Write-Host "=================================================================================="
Read-Host "Appuyez sur Entrée UNE FOIS QUE LES 3 SERVICES SONT DÉMARRÉS ET PRÊTS..."

Write-Host "`n[4/4] Peuplement de la base de données (test-endpoints)..."
if (Get-Command pwsh -ErrorAction SilentlyContinue) {
    pwsh ./scripts/windows/test-endpoints.ps1
} else {
    powershell ./scripts/windows/test-endpoints.ps1
}

Write-Host "`n========================================="
Write-Host "   ENVIRONNEMENT PRÊT ET PEUPLÉ !        "
Write-Host "========================================="
Write-Host "WORKFLOW POUR INTERAGIR AVEC LE PROJET :"
Write-Host ""
Write-Host "1. Lancer le CLI interactif :"
Write-Host "   > pwsh ./scripts/windows/cli/souq-interactive.ps1"
Write-Host ""
Write-Host "2. Dans le menu du CLI, tester les rôles :"
Write-Host "   - Option [0] : Connectez-vous avec 'dupont@test.com' (Acheteur de base)."
Write-Host "   - Option [0] : Connectez-vous avec 'martin@test.com' (Éditeur)."
Write-Host ""
Write-Host "3. Essayez les fonctionnalités :"
Write-Host "   - En tant qu'acheteur : Acheter un jeu [10], Voir sa bibliothèque [11], Laisser un avis [16]"
Write-Host "   - En tant qu'éditeur : Publier un jeu [8], Publier un DLC [23], Publier un Patch [20]"
Write-Host ""
Write-Host "Amusez-vous bien !"
