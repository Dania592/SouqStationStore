# Documentation - SouqStationStore

Ce répertoire contient la documentation technique et le guide d'utilisation du projet SouqStationStore.

## 🚀 Démarrage Rapide (Recommandé)

Nous avons créé un script interactif **`start.ps1`** situé à la racine du projet. 
Ce script prend en charge l'initialisation de l'environnement de bout en bout.

**Pour lancer le projet via le script :**
1. Ouvrez un terminal (PowerShell recommandé).
2. Lancez la commande suivante à la racine :
   ```powershell
   pwsh ./start.ps1
   ```
3. Suivez les instructions à l'écran :
   - Le script lancera Docker (Kafka, Zookeeper, Registry, Postgres).
   - Il créera les topics Kafka requis.
   - Il vous demandera de lancer vos microservices Spring Boot depuis votre IDE.
   - Il peuplera automatiquement la base de données de test.
   - Il vous expliquera comment lancer le CLI interactif pour tester l'application.

---

## 🛠 Lancement Manuel

Si vous préférez tout lancer manuellement plutôt que d'utiliser `start.ps1`, voici les étapes détaillées :

### 1. Infrastructure (Docker)
```bash
cd infrastructure/docker
docker compose up -d
```
Les services actifs incluent Kafka, Zookeeper, Schema Registry (8085), Kafka-UI (8080) et PostgreSQL.

### 2. Création des topics Kafka
Depuis la racine :
```bash
./scripts/setup-kafka-topics.sh
```

### 3. Lancement des Services Spring Boot
- `platform-service` (Port 8081)
- `publisher-service` (Port 8082)
- `notification-service` (Port 8083)

### 4. Tests et Peuplement (Optionnel)
Exécutez l'un des scripts suivants pour générer des données factices complètes :
- En bash : `./scripts/test-endpoints.sh`
- En PowerShell : `pwsh ./scripts/test-endpoints.ps1`

---

## 🎮 Interagir via le CLI Interactif

Un script **PowerShell complet** permet de tester toutes les fonctionnalités avec un menu interactif ! C'est le moyen recommandé pour interagir avec le système de la manière la plus ergonomique qui soit.

```powershell
pwsh ./scripts/cli/souq-interactive.ps1
```

**Principaux comptes de test injectés par le script `test-endpoints` :**
- **Utilisateurs Acheteurs :** 
  - `dupont@test.com` (U100)
  - `martin.acheteur@test.com` (U200)
- **Éditeur / Vendeur :**
  - `martin@test.com` (R200)

___

## ✨ Vue d'ensemble des Fonctionnalités Implémentées

### 1. Gestion du Catalogue (Catalog)
Découverte et navigation des jeux publiés par les éditeurs. Filtrage (genre, plateforme) et visualisation des métadonnées ainsi que le calcul automatique du stock et des ventes.

### 2. Gestion des Achats (Purchases)
Achats directs de jeux/DLC pour les joueurs avec déduction de solde. Ajout à la bibliothèque et vérification instantanée de possession (ownership).

### 3. Social & Editeurs (Follows)
Système social permettant de suivre d'autres utilisateurs ou des éditeurs de jeux pour recevoir leurs notifications de nouvelles sorties de jeux.

### 4. Sessions de Jeu (Playtime)
Les joueurs peuvent "démarrer" et "arrêter" des sessions de jeu, déclenchant des notifications de l'autre côté.

### 5. Avis et Notes (Reviews & Ratings)
Dépôt d'avis vérifié (seulement si le jeu est possédé). Les utilisateurs peuvent voter pour désigner si un avis rédigé par un autre utilisateur leur a été utile.

### 6. Signalements de Bugs (Incidents)
Remontée de bugs par les joueurs directement depuis la plateforme, capturable par les éditeurs.

### 7. Actions Éditeurs (Patches & DLC)
Espace réservé aux vendeurs pour la publication de nouveautés (extensions DLC) ou la mise à disposition de mises à jour via des "Patchs" modifiant de façon asynchrone les versions listées sur le catalogue global.

### 8. Puits de Notifications (Notification-Service)
Service de capture et d'historisation des événements Kafka. Centralise via format Avro toutes les alertes asynchrones remontées depuis l'activité du site et des publications (Achat, Dépôt d'avis, Nouveaux Patches, etc...).

---
*Ce guide vise à assurer que tous les membres de l'équipe travaillant sur `SouqStationStore` possèdent la même vision et les mêmes outils pour opérer efficacement localement.*
