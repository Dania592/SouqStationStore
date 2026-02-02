# SouqStationStore
Ce projet vise à concevoir et implémenter une architecture orientée événements pour une plateforme de jeux vidéo.
Les différentes parties prenantes (éditeurs, plateformes et joueurs) communiquent de manière **asynchrone** via des **flux d’événements**, afin de gérer la publication de jeux, les mises à jour, les évaluations et les rapports d’incidents.

Le projet s’inscrit dans le cadre des modules **Langages de la JVM** et **Ingénierie des données**.

## Architecture
- Applications indépendantes communiquant via Kafka
- Échanges asynchrones avec garantie *at-least-once*
- Contrats de données versionnés (Schema Registry)
- Traitements orientés événements (publication, consommation, routage)