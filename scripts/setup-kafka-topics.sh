#!/usr/bin/env bash
set -euo pipefail

KAFKA_CONTAINER=$(docker ps --filter "ancestor=confluentinc/cp-kafka:7.6.1" --format "{{.ID}}")

if [ -z "$KAFKA_CONTAINER" ]; then
  echo "❌ Kafka container not found. Is docker-compose running?"
  exit 1
fi

create_topic () {
  local topic=$1
  local partitions=${2:-3}
  local rf=${3:-1}

  echo "Creating topic: $topic"
  docker exec -i "$KAFKA_CONTAINER" \
    kafka-topics \
    --bootstrap-server kafka:9092 \
    --create --if-not-exists \
    --topic "$topic" \
    --partitions "$partitions" \
    --replication-factor "$rf"
}

create_topic "souq.publisher.events" 3 1
create_topic "souq.platform.user.events" 3 1
create_topic "souq.platform.redactor.events" 3 1
create_topic "souq.platform.purchase.events" 3 1
create_topic "souq.platform.review.events" 3 1
create_topic "souq.platform.incident.events" 3 1
create_topic "souq.dlq.events" 1 1

echo "✅ Topics created successfully"
