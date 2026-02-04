# SouqStationStore
Ce projet vise à concevoir et implémenter une architecture orientée événements pour une plateforme de jeux vidéo.
Les différentes parties prenantes (éditeurs, plateformes et joueurs) communiquent de manière **asynchrone** via des **flux d’événements**, afin de gérer la publication de jeux, les mises à jour, les évaluations et les rapports d’incidents.

Le projet s’inscrit dans le cadre des modules **Langages de la JVM** et **Ingénierie des données**.

## Architecture
- Applications indépendantes communiquant via Kafka
- Échanges asynchrones avec garantie *at-least-once*
- Contrats de données versionnés (Schema Registry)
- Traitements orientés événements (publication, consommation, routage)

## Structure proposée V1
### Structure générale 
souqstationstore/
│
├── schemas/
├── shared/
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
│   ├── user-registered.avsc
│   ├── game-purchased.avsc
│   ├── review-submitted.avsc
│   ├── comment-submitted.avsc
│   ├── incident-reported.avsc
│   └── user-notification.avsc
│
└── models/
├── game.avsc
├── patch.avsc
├── user.avsc
├── publisher.avsc
└── review.avsc

| Fichier                | Type       | Rôle                                  |
| ---------------------- | ---------- | ------------------------------------- |
| game-published.avsc    | Avro Event | Publication d’un nouveau jeu          |
| patch-published.avsc   | Avro Event | Publication d’un correctif            |
| user-registered.avsc   | Avro Event | Inscription d’un utilisateur          |
| game-purchased.avsc    | Avro Event | Achat d’un jeu                        |
| review-submitted.avsc  | Avro Event | Soumission d’une évaluation           |
| comment-submitted.avsc | Avro Event | Soumission d’un commentaire           |
| incident-reported.avsc | Avro Event | Signalement d’un incident             |
| user-notification.avsc | Avro Event | Notification envoyée à un utilisateur |

| Fichier        | Type       | Rôle                       |
| -------------- | ---------- | -------------------------- |
| game.avsc      | Avro Model | Structure d’un jeu         |
| patch.avsc     | Avro Model | Structure d’un correctif   |
| user.avsc      | Avro Model | Structure utilisateur      |
| publisher.avsc | Avro Model | Structure éditeur          |
| review.avsc    | Avro Model | Structure d’une évaluation |


#### Shared :
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

| Fichier            | Type         | Rôle                                       |
| ------------------ | ------------ | ------------------------------------------ |
| DomainEvent.java   | Interface    | Contrat commun de tous les événements      |
| EventEnvelope.java | Classe       | Métadonnées : eventId, type, date, version |
| GameGenre.java     | Enum         | Genres de jeux                             |
| Platform.java      | Enum         | Plateformes (PC, Console…)                 |
| Version.java       | Value Object | Gestion des versions                       |


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

| Fichier                      | Type            | Rôle                             |
| ---------------------------- | --------------- | -------------------------------- |
| PublisherController.java     | REST Controller | API éditeur                      |
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

| Fichier                   | Type           | Rôle                        |
| ------------------------- | -------------- | --------------------------- |
| NotificationService.java  | Service        | Routage des notifications   |
| MultiEventConsumer.java   | Kafka Consumer | Écoute plusieurs événements |
| NotificationProducer.java | Kafka Producer | Envoi notifications         |

#### Infrastructure 
infrastructure/
├── docker/
│   ├── docker-compose.yml
│   ├── kafka/
│   └── postgres/
│       └── init.sql

| Fichier            | Type   | Rôle                      |
| ------------------ | ------ | ------------------------- |
| docker-compose.yml | Docker | Kafka, Registry, Postgres |
| init.sql           | SQL    | Initialisation DB         |

#### Scripts 
scripts/
├── setup-kafka-topics.sh
├── register-schemas.sh
└── load-test-data.sh


## Topics Kafka recommandés :
- souq.publisher.events : tout ce que publie l’éditeur (jeux + patchs)
- souq.platform.events : tout ce que publie la plateforme (users + achats + reviews + incidents)
- souq.notification.events : sorties finales de notifications

## clés Kafka V0
**souq.publisher.events** (GamePublished, PatchPublished)
key = gameId

**souq.platform.events**
UserRegistered → key = userId
GamePurchased → key = userId (histoire achat par user)
ReviewSubmitted → key = gameId (agrégation par jeu)
IncidentReported → key = gameId (suivi incident par jeu)

**souq.notification.events** (UserNotification)
key = userId