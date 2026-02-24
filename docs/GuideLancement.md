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
notification-service 

## Tests pour chaque fonctionnalité
### Création d'un user : 
```bash
curl -X POST "http://localhost:8081/platform/register-user" \
-d "userId=U100" \
-d "name=Dupont" \
-d "email=dupont@test.com" \
-d "displayName=JeanD" \
-d "birth=1990-05-12" \
-d "solde=100.5"

// ou 
http://localhost:8081/platform/register-user?userId=U100&name=Dupont&email=dupont@test.com&displayName=JeanD&birth=1990-05-12&solde=100.5
````

### Création d'un redactor 
```bash
curl -X POST "http://localhost:8081/platform/register-redactor" \
-d "userId=R200" \
-d "name=Martin" \
-d "email=martin@test.com" \
-d "displayName=MarcM" \
-d "birth=1985-08-20" \
-d "solde=250.75" \
-d "individual=true"

// ou 
http://localhost:8081/platform/register-redactor?userId=R200&name=Martin&email=martin%40test.com&displayName=MarcM&birth=1985-08-20&solde=250.75&individual=true
```

### Publication de jeu par un redactor
```bash
http://localhost:8082/publisher/publish-game?gameId=G300&title=The%20Witcher%203&description=Open%20world%20RPG&platform=PC&genre=RPG&idEditeur=R200&version=1.0&price=39.99&releaseDate=2025-10-10
```


## Test de fonctionnement 
http://localhost:8082/publisher/publish-game?gameId=game-1&title=bonjour&description=un%20jeu%20cool&platform=PC&genre=ACTION&idEditeur=ed-1
### retour 
```json
{
  "idEditeur": "ed-1",
  "eventId": "8917e233-f004-4df6-9f96-41c1e6916c27",
  "description": "un jeu cool",
  "genre": "ACTION",
  "status": "PUBLISHED_TO_KAFKA",
  "gameId": "game-1",
  "title": "bonjour",
  "occurredAt": "2026-02-18T22:11:43.995899900Z",
  "platform": "PC"
}
```
- vérification dans Kafka UI : http://localhost:8080
  → Topics → souq.publisher.events → Messages

## Test de notification 
```bash
docker exec -it docker-kafka-1 bash

kafka-console-producer \
  --bootstrap-server kafka:9092 \
  --topic souq.platform.events \
  --property "parse.key=true" \
  --property "key.separator=:" << 'EOF'
game-1:{"eventId":"evt-002","eventType":"IncidentReported","occurredAt":"2026-02-10T12:01:00Z","schemaVersion":1,"payload":{"userId":"user-1","gameId":"game-1","description":"Crash au lancement"}}
EOF

kafka-console-producer \
  --bootstrap-server kafka:9092 \
  --topic souq.platform.events \
  --property "parse.key=true" \
  --property "key.separator=:" << 'EOF'
user-1:{"eventId":"evt-001","eventType":"GamePurchased","occurredAt":"2026-02-10T12:00:00Z","schemaVersion":1,"payload":{"userId":"user-1","gameId":"game-1"}}
EOF
```

## Création d'utilisateur 
http://localhost:8081/platform/register-user?userId=user-1&name=Jean%20Dupont&email=jean@mail.com&displayName=JeanGamer&birth=1995-05-12
```bash
 docker exec -it docker-postgres-1  psql -U souq souq
 select * from users;
```