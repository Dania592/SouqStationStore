# ✅ Next Step — Passer du “_unpack Kafka_” à une base **robuste** (idempotence + persistence)

Vous avez validé le **Hello World Kafka** :
- les topics existent
- le producer publie
- le consumer reçoit
- les messages sont visibles dans Kafka UI

👉 La prochaine étape logique est d’ajouter la **robustesse minimum** exigée par une architecture event-driven :
## 🎯 Objectif de cette étape
Mettre en place :
1) **une base de données** (Postgres) utilisée par le service
2) une **table d’idempotence** `consumed_events` pour gérer le *at-least-once*
3) une **logique consumer** qui :
    - ignore les doublons (même event reçu plusieurs fois)
    - ACK seulement après traitement réussi

---

## Pourquoi c’est important ?

Kafka en *at-least-once* signifie :
- un message peut être re-livré (redelivery)
- un consumer peut traiter deux fois le même event

Sans idempotence, vous aurez :
- des doublons dans la DB
- des effets secondaires répétés (catalogue, achats, notifications…)

✅ L’idempotence est la **bonne pratique minimale** pour être “robuste”.

---

# Étape 1 — Ajouter la dépendance DB + JPA au service (platform-service)

## 1.1 Modifier `platform-service/build.gradle`
Ajoutez :

```gradle
implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
runtimeOnly 'org.postgresql:postgresql'
```
Puis dans IntelliJ :

Gradle Tool Window → 🔄 Reload

Build → Rebuild Project

### ETAPE 2 - configuration de la connexion Postgres 
- modification de platform-serice=> application.yml en ajoutant :
```yml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/souq
    username: souq
    password: souq
  jpa:
    hibernate:
      ddl-auto: update
    properties:
      hibernate:
        format_sql: true
```

suite : https://chatgpt.com/share/6983b75c-7020-8001-b787-af48083561c9