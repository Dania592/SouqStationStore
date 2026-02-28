$ErrorActionPreference = "Stop"

$KafkaContainer = docker ps --filter "ancestor=confluentinc/cp-kafka:7.6.1" --format "{{.ID}}"

if (-not $KafkaContainer) {
    Write-Host "❌ Kafka container not found. Is docker-compose running?"
    exit 1
}

function Create-Topic {
    param(
        [string]$Topic,
        [int]$Partitions = 3,
        [int]$ReplicationFactor = 1
    )
    Write-Host "Creating topic: $Topic"
    docker exec -i $KafkaContainer `
        kafka-topics `
        --bootstrap-server kafka:9092 `
        --create --if-not-exists `
        --topic $Topic `
        --partitions $Partitions `
        --replication-factor $ReplicationFactor
}

Create-Topic -Topic "souq.publisher.events" -Partitions 3 -ReplicationFactor 1
Create-Topic -Topic "souq.publisher.patch.events" -Partitions 3 -ReplicationFactor 1
Create-Topic -Topic "souq.platform.user.events" -Partitions 3 -ReplicationFactor 1
Create-Topic -Topic "souq.platform.redactor.events" -Partitions 3 -ReplicationFactor 1
Create-Topic -Topic "souq.platform.purchase.events" -Partitions 3 -ReplicationFactor 1
Create-Topic -Topic "souq.platform.review.events" -Partitions 3 -ReplicationFactor 1
Create-Topic -Topic "souq.platform.review-rated.events" -Partitions 3 -ReplicationFactor 1
Create-Topic -Topic "souq.platform.incident.events" -Partitions 3 -ReplicationFactor 1
Create-Topic -Topic "souq.dlq.events" -Partitions 1 -ReplicationFactor 1

Write-Host "✅ Topics created successfully"
