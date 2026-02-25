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

### Follow d'un utilisateur à un autre  
```bash
http://localhost:8081/platform/users/follow?userId=U100&followedId=U200
```