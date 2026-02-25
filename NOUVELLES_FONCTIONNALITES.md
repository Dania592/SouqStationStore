# ✅ NOUVELLES FONCTIONNALITÉS IMPLÉMENTÉES

## 1. GESTION D'ACHATS (platform-service)

### Fichiers créés
- `persistence/GamePurchaseEntity.java`
- `persistence/GamePurchaseRepository.java`
- `messaging/PlatformPurchaseEventProducer.java`
- `service/PurchaseService.java`
- `api/PurchaseController.java`

### Endpoints
- `POST /platform/purchases/game` - Acheter un jeu
- `GET /platform/purchases/library` - Bibliothèque utilisateur
- `GET /platform/purchases/owns` - Vérifier possession
- `GET /platform/purchases/sales-count` - Statistiques ventes

### Logique métier
- Vérifier user existe + jeu existe + pas déjà possédé + solde suffisant
- Déduire balance via `user.deductBalance()`
- Sauvegarder achat → Publier `GamePurchasedEvent`

---

## 2. GESTION CATALOGUE (platform-service)

### Fichiers créés
- `persistence/GameCatalogEntity.java`
- `persistence/GameCatalogRepository.java`
- `service/CatalogService.java`
- `api/CatalogController.java`

### Fichiers modifiés
- `messaging/PublisherEventsConsumer.java` - Consomme GamePublished → ajoute au catalogue

### Endpoints
- `GET /platform/catalog/games` - Liste jeux (filtres: genre, platform, maxPrice)
- `GET /platform/catalog/games/{gameId}` - Détails jeu
- `GET /platform/catalog/publishers/{publisherId}/games` - Jeux par éditeur
- `GET /platform/catalog/publishers/{publisherId}/count` - Nombre de jeux

### Logique métier
- Consommer `GamePublished` → sauvegarder dans catalogue
- Filtrage par genre/plateforme/prix
- Mise à jour version via `updateGameVersion()`

---

## 3. GESTION REVIEWS (platform-service)

### Fichiers créés
- `persistence/ReviewEntity.java`
- `persistence/ReviewRatingEntity.java`
- `persistence/ReviewRepository.java`
- `persistence/ReviewRatingRepository.java`
- `messaging/PlatformReviewEventProducer.java`
- `service/ReviewService.java`
- `api/ReviewController.java`

### Endpoints
- `POST /platform/reviews/submit` - Soumettre review
- `POST /platform/reviews/{reviewId}/rate` - Noter review (utile/pas utile)
- `GET /platform/reviews/game/{gameId}` - Reviews d'un jeu
- `GET /platform/reviews/user/{userId}` - Reviews d'un utilisateur

### Logique métier
- Vérifier user possède le jeu + pas déjà reviewé + note valide (0-10)
- Compteurs helpful/unhelpful avec gestion changement de vote
- Publier `ReviewSubmittedEvent` et `ReviewRatedEvent`

---

## 4. GESTION INCIDENTS (platform-service)

### Fichiers créés
- `persistence/IncidentEntity.java` (enum Severity: CRITIQUE/HAUTE/NORMALE/BASSE)
- `persistence/IncidentRepository.java`
- `messaging/PlatformIncidentEventProducer.java`
- `service/IncidentService.java`
- `api/IncidentController.java`

### Endpoints
- `POST /platform/incidents/report` - Signaler incident
- `GET /platform/incidents/game/{gameId}` - Incidents d'un jeu (filtre severity)
- `GET /platform/incidents/game/{gameId}/count` - Compter incidents

### Logique métier
- Vérifier jeu existe dans catalogue + parser severity
- Filtrage par sévérité
- Publier `IncidentReportedEvent`

---

## 5. GESTION PATCHES (publisher-service)

### Fichiers créés
- `persistence/PatchEntity.java` (enum ModificationType: CORRECTION/AJOUT/OPTIMISATION)
- `persistence/PatchRepository.java`
- `messaging/PublisherPatchEventProducer.java`
- `service/PatchService.java`

### Fichiers modifiés
- `persistence/GameEntity.java` - Ajout `setVersion()`
- `api/PublisherController.java` - Injection PatchService + nouveaux endpoints

### Endpoints
- `POST /publisher/publish-patch` - Publier patch
- `GET /publisher/games/{gameId}/patches` - Historique patches

### Logique métier
- Vérifier jeu existe + version différente + version unique
- **Mise à jour automatique version du jeu**
- Publier `PatchPublishedEvent`

---

## 6. GESTION DLC (publisher-service + platform-service)

### Fichiers créés (publisher-service)
- `persistence/DLCEntity.java`
- `persistence/DLCRepository.java`
- `messaging/PublisherDLCEventProducer.java`
- `service/DLCService.java`

### Fichiers créés (platform-service)
- `persistence/DLCPurchaseEntity.java`
- `persistence/DLCPurchaseRepository.java`
- `persistence/DLCCatalogEntity.java`
- `persistence/DLCCatalogRepository.java`
- `messaging/PlatformDLCPurchaseEventProducer.java`

### Fichiers modifiés
- `api/PublisherController.java` - Endpoints publication DLC
- `service/PurchaseService.java` - Méthode achat DLC
- `api/PurchaseController.java` - Endpoints achat DLC
- `service/CatalogService.java` - Méthode ajout DLC catalogue
- `messaging/PublisherEventsConsumer.java` - Consommation DLCPublishedEvent

### Endpoints (publisher-service)
- `POST /publisher/publish-dlc` - Publier DLC
- `GET /publisher/games/{gameId}/dlcs` - Liste DLC d'un jeu

### Endpoints (platform-service)
- `POST /platform/purchases/dlc` - Acheter DLC
- `GET /platform/purchases/dlcs` - DLC possédés

### Logique métier
- **Vérifier user possède le jeu de base avant achat DLC**
- Publier `DLCPublishedEvent` → ajouté au catalogue
- Publier `DLCPurchasedEvent`

---

## 7. CONSOMMATION RETOURS UTILISATEURS (publisher-service)

### Fichiers créés
- `persistence/ReceivedReviewEntity.java`
- `persistence/ReceivedReviewRepository.java`
- `persistence/ReceivedIncidentEntity.java`
- `persistence/ReceivedIncidentRepository.java`
- `messaging/ReviewConsumer.java`
- `messaging/IncidentConsumer.java`

### Fichiers modifiés
- `application.yml` - Topics platform.review et platform.incident

### Logique métier
- Consommer `ReviewSubmittedEvent` → stocker dans ReceivedReviewEntity
- Consommer `IncidentReportedEvent` → stocker dans ReceivedIncidentEntity
- **Idempotence via ConsumedEventEntity**
- Permet aux éditeurs de monitorer avis/bugs sur leurs jeux

---

## 📋 CONFIGURATIONS

### application.yml (platform-service)
```yaml
souq.kafka.topics.platform:
  purchase: souq.platform.purchase.events
  review: souq.platform.review.events
  incident: souq.platform.incident.events
```

### application.yml (publisher-service)
```yaml
souq.topics:
  publisher: souq.publisher.events
  platform:
    review: souq.platform.review.events
    incident: souq.platform.incident.events
```

### setup-kafka-topics.sh
```bash
souq.platform.purchase.events
souq.platform.review.events
souq.platform.incident.events
souq.publisher.events
```

### Modifications UserEntity
- Ajout `setSolde(float solde)`
- Ajout `deductBalance(double amount)`

---

**Date** : 25 février 2026  
**Patterns respectés** : JPA entities, @Transactional, Avro events, manual ACK Kafka  
**Event Flow** : Bidirectionnel (publisher→platform + platform→publisher)
