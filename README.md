# SouqStationStore

Ce projet vise à concevoir et implémenter une **architecture orientée événements** robuste pour une plateforme numérique de distribution de jeux vidéo (type Steam/Epic Games). 
Les différentes parties prenantes (éditeurs, plateforme et joueurs) communiquent de manière asynchrone via des flux d’événements Kafka afin de gérer finement les catalogues, les achats, les retours communautaires (avis, incidents) et les mises à jour en continu.

Le projet s’inscrit dans le cadre des modules **Langages de la JVM** et **Ingénierie des données** à Polytech (Février 2026).

---

## 🏛 Architecture Technique

L'écosystème repose sur des microservices découplés :
- **Communication Asynchrone** : Kafka avec sémantique *at-least-once* et acheminement robuste.
- **Contrats de Données** : Utilisation d'**Avro** avec le Confluent Schema Registry (8085) pour typer fortement et versionner les événements métiers.
- **Persistance** : PostgreSQL (5432) mutualisée, attaquée via Spring Data JPA avec gestion transactionnelle complète.
- **Technologie Core** : Spring Boot 3.4.2 (Java 21), Gradle.

---

## 🚀 Lancement & Utilisation Rapide

Le processus de lancement a été entièrement industrialisé grâce à des scripts cross-platforms garantissant une mise en place en une seule commande (Docker, Kafka, Topics et Peuplement de DB inclus).

La documentation technique complète ainsi que les instructions de lancement et la description des Endpoints REST sont disponibles dans :
👉 **[`docs/GuideLancement.md`](docs/GuideLancement.md)**

Un **CLI Interactif (Shell interactif)** est également fourni pour expérimenter toutes les fonctionnalités métier de façon ergonomique.

---

## 📦 Les Microservices

Le système est constitué de trois services indépendants assurant chacun des responsabilités métiers isolées (Séparation des préoccupations).

### 1. Platform Service (`8081`)
C'est le cœur de l'application côté joueur.
- **Acheteurs & Profils** : Gestion du solde financier, et du système social (Followers d'autres joueurs ou éditeurs).
- **Catalogue & Achat** : Découverte des jeux (issus des événements Kafka du *Publisher*), transactions financières et gestion de la "Bibliothèque" (Ownership).
- **Communauté** : Dépôt d'évaluations (Reviews), vote d'utilité (Helpful/Unhelpful) et signalement d'incidents par niveaux de criticité.
- **Statistiques** : Détection des lancements de session de jeu et calcul du temps de jeu (Playtime).

### 2. Publisher Service (`8082`)
L'espace dédié aux développeurs et éditeurs de contenu.
- **Distributions Initiales** : Publication de jeux de base via le réseau Kafka (`GamePublishedEvent`).
- **Nouveaux Contenus** : Déploiement d'extensions Payantes (DLCs).
- **Gestion du Cycle de Vie** : Déploiement de Correctifs et Mises à jour (`PatchPublishedEvent`).
- **Analyse des retours** : Le service consomme et agrège activement les métriques de la plateforme (avis, bugs) pour permettre aux éditeurs d'ajuster leurs stratégies.

### 3. Notification Service (`8083`)
Puits asynchrone passif (Sink).
- Consomme de manière agnostique la très grande majorité des événements critiques du système (Achats, Bugs, Mises à jour, Nouveaux abonnements).
- Génère, stocke et délivre les notifications asynchrones aux utilisateurs (Notifications internes persistées).

---

## 📡 Flux Événementiels & Kafka (Topologies)

Afin d'éviter de coûteux conflits de schémas au sein du Schema Registry Confluent (Erreur 409) et d'assurer une scalabilité des partitions, les événements ont été rigoureusement ségrégués en différents *Topics* dédiés par domaine.

**Domaine Éditeur (Publisher -> Platform/Notifs)** :
- `souq.publisher.events` : Publications de jeux et DLC (`gameId`).
- `souq.publisher.patch.events` : Mises à jour correctives (`gameId`).

**Domaine Plateforme (Platform -> Publisher/Notifs)** :
- `souq.platform.user.events` : Activités sociales (`userId`).
- `souq.platform.purchase.events` : Transactions financières approuvées (`userId`).
- `souq.platform.review.events` : Soumission de nouvelles évaluations communautaires (`gameId`).
- `souq.platform.review-rated.events` : Notation de pertinence d'une évaluation (`reviewId`).
- `souq.platform.incident.events` : Signalements de bugs / crashs (`gameId`).

**Domaine Internes** :
- `souq.dlq.events` : *Dead Letter Queue* pour le routage des événements en échec de sérialisation ou corrompus.

---

## 📂 Organisation du Dépôt

```
SouqStationStore/
├── schemas/                 # Modules Avro (Contrats .avsc mutualisés et générés)
├── publisher-service/       # Microservice Editeur
├── platform-service/        # Microservice Acheteur / Plateforme
├── notification-service/    # Microservice Centralisation des Alertes
├── infrastructure/docker/   # Fichiers docker-compose (Kafka, Zookeeper, Registry, Postgres)
├── docs/                    # Documentations (GuideLancement.md)
├── scripts/                 # Scripts utilitaires utiles au cycle de vie
│   ├── linux/               # Utilitaires Shell (CLI interactif, Création topics, Seed base de test)
│   └── windows/             # Équivalents PowerShell
├── start.sh                 # Lanceur rapide global pour Linux / Mac
└── start.ps1                # Lanceur rapide global pour Windows
```

---
*Projet réalisé pour la validation du module JVM & Ingénierie des Données - 2026.*
