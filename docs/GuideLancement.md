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
http://localhost:8082/publisher/publish-game?gameId=G300&title=The%20Witcher%203&description=Open%20world%20RPG&platform=PC&genre=RPG&idEditeur=R200&version=1.0&prixInit=39.99&releaseDate=2025-10-10
```

### Follow d'un utilisateur à un autre  
```bash
http://localhost:8081/platform/users/follow?userId=U100&followedId=U200
```

### Achat d'un jeu
```bash
curl -X POST "http://localhost:8081/platform/purchases/game" \
-d "userId=U100" \
-d "gameId=G300"
```

### Consultation de la bibliothèque d'un utilisateur
```bash
curl "http://localhost:8081/platform/purchases/library?userId=U100"
```

### Dépôt d'un avis (Review) sur un jeu
```bash
curl -X POST "http://localhost:8081/platform/reviews/submit" \
-d "userId=U100" \
-d "gameId=G300" \
-d "note=9" \
-d "description=Incroyable !"
```

### Noter l'avis d'un autre utilisateur comme utile (Rate)
*(Remplacer `REVIEW_ID` par l'ID réel généré par la commande précédente)*
```bash
curl -X POST "http://localhost:8081/platform/reviews/REVIEW_ID/rate" \
-d "userId=U200" \
-d "isHelpful=true"
```

### Signalement d'un bug / incident en jeu
Les options de gravité (`severity`) valides : `CRITIQUE`, `HAUTE`, `NORMALE`, `BASSE`.
```bash
curl -X POST "http://localhost:8081/platform/incidents/report" \
-d "userId=U100" \
-d "gameId=G300" \
-d "severity=HAUTE" \
-d "description=Crashs%20intempestifs" \
-d "environment=Windows%2011"
```

### Publication d'un patch par l'éditeur
Les options de modifications (`modifications`) valides : `CORRECTION`, `AJOUT`, `OPTIMISATION`.
```bash
curl -X POST "http://localhost:8082/publisher/publish-patch" \
-d "gameId=G300" \
-d "targetVersion=1.0.1" \
-d "patchNotes=Correction%20du%20crash%20sous%20Windows%2011" \
-d "releasedAt=2025-11-20" \
--data-urlencode "modifications=CORRECTION" \
--data-urlencode "modifications=OPTIMISATION"
```

### Vérifier le statut du jeu modifié (sur la plateforme)
```bash
curl "http://localhost:8081/platform/catalog/games/G300"
```

### Check de feedback reviews 
```bash
http://localhost:8081/platform/feedback/reviews?gameId=G340
```

### check des incidents
```bash
http://localhost:8081/platform/feedback/incidents?gameId=G340"
```

### Consultation de statistiques 
```bash
http://localhost:8081/platform/feedback/reviews/g1/stats
```

### Lancement d'un jeu 
```bash
http://localhost:8081/platform/sessions/start?userId=ma&gameId=G340
```

### Fin de jeu 
```bash
http://localhost:8081/platform/sessions/end?userId=ma&gameId=G340
```

### Consultation des stats 
```bash
http://localhost:8081/platform/sessions/users/ma/playtime?gameId=G340
```



