# SouqStationStore

Ce projet vise à concevoir et implémenter une architecture orientée événements pour une plateforme de jeux vidéo.
Les différentes parties prenantes (éditeurs, plateformes et joueurs) communiquent de manière **asynchrone** via des **flux d’événements**, afin de gérer la publication de jeux, les mises à jour, les évaluations et les rapports d’incidents.

Le projet s’inscrit dans le cadre des modules **Langages de la JVM** et **Ingénierie des données**.

## Architecture

- Applications indépendantes communiquant via Kafka
- Échanges asynchrones avec garantie *at-least-once*
- Contrats de données versionnés (Schema Registry)
- Traitements orientés événements (publication, consommation, routage)

## Guide de lancement

Voir le fichier : docs/GuideLancement.md

## Etat Actuel (Février 2026)

L'infrastructure est opérationnelle et les flux d'événements principaux ont été validés. Le problème critique de conflit de schémas Avro (Erreur 409 Schema Registry) a été résolu en adoptant une stratégie `RecordNameStrategy` couplée à une ségrégation des topics par domaine (Patchs séparés des Jeux, Avis évalués séparés des Dépôts d'avis). La persistance fonctionne corrèctement sur la PostgreSQL de Platform Service.

### Services Operationnels


| Service              | Port | Statut   | Description                                                     |
| -------------------- | ---- | -------- | --------------------------------------------------------------- |
| platform-service     | 8081 | En cours | Gestion des utilisateurs, consommation des evenements publisher |
| publisher-service    | 8082 | En cours | Publie les jeux et patchs vers Kafka                            |
| notification-service | 8083 | En cours | Route les evenements vers les notifications utilisateurs        |

### Statut de l'Infrastructure
 => à revoir (les ports)

| Composant              | Port  | Statut                              |
| ---------------------- | ----- | ----------------------------------- |
| Kafka (docker interne) | 9092  | En cours                            |
| Kafka (acces host)     | 29092 | En cours                            |
| Zookeeper              | 2181  | En cours                            |
| Schema Registry        | 8085  | En cours (non utilise actuellement) |
| PostgreSQL             | 5432  | En cours                            |
| Kafka UI               | 8080  | En cours                            |

### Flux End-to-End Valide

L'architecture est en place et les scenarios les plus simples sont realisables. On peut publier un jeu, emettre un achat via la CLI, et retrouver la notification correspondante en base.

```bash
sudo ./scripts/cli/souq.sh event purchase user-1 game-1
curl http://localhost:8083/notifications/user-1
```

### Guide des Commandes Curl HTTP

> **Important** : L'ensemble des appels HTTP (Création compte, Achat, Signalement, Ajout Patch...) se trouvent désormais regroupés dans :
> 👉 **`docs/GuideLancement.md`**

### Modifications Réalisées Récemment

- **Ajustement Kafka & Avro** : Configuration de `io.confluent.kafka.serializers.subject.RecordNameStrategy` pour permettre le mulitplexage d'événements sur certains topics.
- **Création de Nouveaux Topics** : L'enfer du Subject Name a été réglé en isolant les `PatchPublishedEvent` et `ReviewRatedEvent` dans leurs propres topics dédiés (dans Publisher et Platform).
- **Correctifs Applicatifs** : Correction d'une NullPointerException dans `PublisherController` et ajout des paramètres manquants aux appels de base de données.
- **Mise à jour Spring Boot** : De 3.3.2 vers 3.4.2 pour la compatibilité JDK.

## Structure proposée V1

### Structure générale

souqstationstore/
│
├── schemas/
├── publisher-service/
├── platform-service/
├── notification-service/
├── infrastructure/
├── scripts/
│
├── build.gradle
├── settings.gradle
├── gradlew
├── .gitignore
└── README.md

### Détails des modules

#### Schemas : contrats de données

Contient tous les schémas Avro utilisés pour les échanges Kafka.
Ces schémas garantissent la compatibilité entre producteurs et consommateurs.

schemas/
├── events/
│   ├── game-published.avsc
│   ├── patch-published.avsc
│   ├── dlc-published.avsc
│   ├── user-registered.avsc
│   ├── game-purchased.avsc
│   ├── dlc-purchased.avsc
│   ├── review-submitted.avsc
│   ├── review-rated.avsc
│   ├── comment-submitted.avsc
│   ├── incident-reported.avsc
│   └── user-notification.avsc
│
└── models/
├── game.avsc
├── patch.avsc
├── dlc.avsc
├── user.avsc
├── publisher.avsc
├── review.avsc
└── purchase.avsc


| Fichier                | Type       | Rôle                                   |
| ---------------------- | ---------- | --------------------------------------- |
| game-published.avsc    | Avro Event | Publication d’un nouveau jeu           |
| patch-published.avsc   | Avro Event | Publication d’un correctif             |
| dlc-published.avsc     | Avro Event | Publication d'un DLC                   |
| user-registered.avsc   | Avro Event | Inscription d'un utilisateur           |
| game-purchased.avsc    | Avro Event | Achat d'un jeu                         |
| dlc-purchased.avsc     | Avro Event | Achat d'un DLC                         |
| review-submitted.avsc  | Avro Event | Soumission d'une évaluation           |
| review-rated.avsc      | Avro Event | Notation d'une évaluation (utile/pas utile) |
| comment-submitted.avsc | Avro Event | Soumission d'un commentaire            |
| incident-reported.avsc | Avro Event | Signalement d'un incident              |
| user-notification.avsc | Avro Event | Notification envoyée à un utilisateur |



| Fichier        | Type       | Rôle                        |
| -------------- | ---------- | ---------------------------- |
| game.avsc      | Avro Model | Structure d’un jeu          |
| patch.avsc     | Avro Model | Structure d’un correctif    |
| dlc.avsc       | Avro Model | Structure d'un DLC          |
| user.avsc      | Avro Model | Structure utilisateur        |
| publisher.avsc | Avro Model | Structure éditeur           |
| review.avsc    | Avro Model | Structure d'une évaluation |
| purchase.avsc  | Avro Model | Structure d'une transaction |

#### Shared : VIDE POUR L'INSTANT 

Contient les éléments partagés entre tous les services.
shared/
└── src/main/java/com/souqstation/shared/
├── events/
│   ├── DomainEvent.java
│   └── EventEnvelope.java
│
└── domain/
└── valueobjects/
├── GameGenre.java
├── Platform.java
└── Version.java


| Fichier            | Type         | Rôle                                        |
| ------------------ | ------------ | -------------------------------------------- |
| DomainEvent.java   | Interface    | Contrat commun de tous les événements      |
| EventEnvelope.java | Classe       | Métadonnées : eventId, type, date, version |
| GameGenre.java     | Enum         | Genres de jeux                               |
| Platform.java      | Enum         | Plateformes (PC, Console…)                  |
| Version.java       | Value Object | Gestion des versions                         |

#### Publisher-service

Responsable de la publication de jeux et de correctifs.
Consomme les retours utilisateurs (reviews, incidents).

publisher-service/
└── src/main/java/com/souqstation/publisher/
├── api/
│   └── PublisherController.java
│
├── service/
│   ├── GamePublicationService.java
│   └── PatchPublicationService.java
│
├── repo/
│   ├── GameRepository.java
│   └── PatchRepository.java
│
└── messaging/
├── KafkaGamePublisher.java
├── KafkaPatchPublisher.java
├── ReviewConsumer.java
└── IncidentConsumer.java


| Fichier                      | Type            | Rôle                            |
| ---------------------------- | --------------- | -------------------------------- |
| PublisherController.java     | REST Controller | API éditeur                     |
| GamePublicationService.java  | Service         | Logique de publication de jeux   |
| PatchPublicationService.java | Service         | Logique de publication de patchs |
| GameRepository.java          | Repository      | Persistance jeux                 |
| PatchRepository.java         | Repository      | Persistance patchs               |
| KafkaGamePublisher.java      | Kafka Producer  | Publie GamePublished             |
| KafkaPatchPublisher.java     | Kafka Producer  | Publie PatchPublished            |
| ReviewConsumer.java          | Kafka Consumer  | Consomme reviews                 |
| IncidentConsumer.java        | Kafka Consumer  | Consomme incidents               |

#### Platform-service

Gère utilisateurs, catalogue, achats, évaluations et incidents.

platform-service/
└── src/main/java/com/souqstation/platform/
├── api/
│   ├── UserController.java
│   ├── CatalogController.java
│   └── PurchaseController.java
│
├── service/
│   ├── UserService.java
│   ├── CatalogService.java
│   ├── PurchaseService.java
│   └── ReviewService.java
│
├── repo/
│   ├── UserRepository.java
│   ├── GameCatalogRepository.java
│   └── PurchaseRepository.java
│
└── messaging/
├── GamePublishedConsumer.java
├── PatchPublishedConsumer.java
├── KafkaUserEventPublisher.java
└── KafkaTransactionPublisher.java

#### Notification-service - Step 2

Centralise et route les notifications.
notification-service/
└── src/main/java/com/souqstation/notification/
├── service/
│   └── NotificationService.java
│
└── messaging/
├── MultiEventConsumer.java
└── NotificationProducer.java


| Fichier                   | Type           | Rôle                          |
| ------------------------- | -------------- | ------------------------------ |
| NotificationService.java  | Service        | Routage des notifications      |
| MultiEventConsumer.java   | Kafka Consumer | Écoute plusieurs événements |
| NotificationProducer.java | Kafka Producer | Envoi notifications            |

#### Infrastructure

infrastructure/
├── docker/
│   ├── docker-compose.yml
│   ├── kafka/
│   └── postgres/
│       └── init.sql


| Fichier            | Type   | Rôle                     |
| ------------------ | ------ | ------------------------- |
| docker-compose.yml | Docker | Kafka, Registry, Postgres |
| init.sql           | SQL    | Initialisation DB         |

#### Scripts

scripts/
├── setup-kafka-topics.sh
├── register-schemas.sh
└── load-test-data.sh

## Topics Kafka recommandés & implémentés :

Pour éviter les limitations du Schema Registry, les topics ont été éclatés de la manière suivante :

**Publisher (`publisher-service`)**
- `souq.publisher.events` : jeux publiés (GamePublished) & DLC
- `souq.publisher.patch.events` : patchs et mises à jour isolées

**Platform (`platform-service`)**
- `souq.platform.user.events` : inscriptions
- `souq.platform.redactor.events` : éditeurs
- `souq.platform.purchase.events` : achats
- `souq.platform.review.events` : dépôt d'avis originaux
- `souq.platform.review-rated.events` : avis notés utiles/inutiles
- `souq.platform.incident.events` : rapports de bugs

**Notification (`notification-service`)**
- `souq.notification.events` : sorties finales de notifications aux joueurs

## clés Kafka V0 recommandées

**Secteur Publisher**
`GamePublished`, `PatchPublished` → key = `gameId`

**Secteur Platform**
`UserRegistered` → key = `userId`
`GamePurchased` → key = `userId` *(histoire d'achat)*
`ReviewSubmitted`, `IncidentReported` → key = `gameId` *(agrégation par jeu)*

**Secteur Notification**
`UserNotification` → key = `userId`
