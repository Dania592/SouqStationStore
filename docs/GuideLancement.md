# Guide de lancement - SouqStationStore
Ce document décrit **les étapes pour lancer le projet localement**, ainsi que les **erreurs fréquentes rencontrées** et leurs **solutions**.

Il est destiné à faciliter le démarrage du projet pour toute l’équipe.

## Lancement de l'infrastructure kafka, Registry, DB 
```bash
cd infrastructure/docker
docker compose up -d
```

### Vérification 
```bash
docker ps
```
Doivent être actifs :
- kafka
- zookeeper
- schema-registry
- kafka-ui => http://localhost:8080
- postgres

## Création des topics Kafka 
```bash
wsl 
./scripts/setup-kafka-topics.sh
```

## Lancement des services Spring Boot 
platform-service (consumer) => 8081
publisher-service (producer) => 8082
- TODO : à compléter par la suite

## Test de fonctionnement 
http://localhost:8082/publisher/publish-game?gameId=game-1&title=Halo
### retour 
```json
{
  "eventId": "bf2ed04a-b347-4a79-8351-e904b56e6da4",
  "eventType": "GamePublished",
  "occurredAt": "2026-02-04T20:59:56.890397300Z",
  "schemaVersion": 1,
  "payload": {
    "gameId": "game-1",
    "title": "Halo"
  }
}
```
- vérification dans Kafka UI : http://localhost:8080
  → Topics → souq.publisher.events → Messages