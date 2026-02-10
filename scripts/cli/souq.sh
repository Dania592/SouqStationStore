#!/usr/bin/env bash
set -euo pipefail

# =========================
# Config (override possible)
# =========================
PUBLISHER_URL="${PUBLISHER_URL:-http://localhost:8082}"
NOTIFICATION_URL="${NOTIFICATION_URL:-http://localhost:8083}"
PLATFORM_URL="${PLATFORM_URL:-http://localhost:8081}"

TOPIC_PUBLISHER="${TOPIC_PUBLISHER:-souq.publisher.events}"
TOPIC_PLATFORM="${TOPIC_PLATFORM:-souq.platform.events}"
TOPIC_NOTIFICATION="${TOPIC_NOTIFICATION:-souq.notification.events}"

BOOTSTRAP_IN_DOCKER="${BOOTSTRAP_IN_DOCKER:-kafka:9092}"

# Container Kafka: par défaut "kafka".
# Si ton nom de container est différent, export KAFKA_CONTAINER_NAME=...
KAFKA_CONTAINER_NAME="${KAFKA_CONTAINER_NAME:-kafka}"

# =========================
# Helpers
# =========================
now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

uuid() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  else
    # fallback (WSL a souvent python3)
    python3 - <<'PY'
import uuid
print(uuid.uuid4())
PY
  fi
}

die() { echo "❌ $*" >&2; exit 1; }

require() { command -v "$1" >/dev/null 2>&1 || die "Commande manquante: $1"; }

detect_kafka_container() {
  # 1) si le container "kafka" existe, ok
  if docker ps --format '{{.Names}}' | grep -qx "${KAFKA_CONTAINER_NAME}"; then
    echo "${KAFKA_CONTAINER_NAME}"
    return
  fi

  # 2) sinon, essayer par image (comme ton script setup topics)
  local id
  id="$(docker ps --filter "ancestor=confluentinc/cp-kafka:7.6.1" --format "{{.ID}}" | head -n 1 || true)"
  if [[ -n "${id}" ]]; then
    echo "${id}"
    return
  fi

  # 3) fallback: premier container contenant "kafka" dans le nom
  local name
  name="$(docker ps --format '{{.Names}}' | grep -i kafka | head -n 1 || true)"
  if [[ -n "${name}" ]]; then
    echo "${name}"
    return
  fi

  die "Kafka container introuvable. Docker compose est-il lancé ?"
}

KAFKA_CONTAINER="$(detect_kafka_container)"

kafka_produce() {
  local topic="$1"
  local key="$2"
  local json="$3"

  # key:value sur stdin
  docker exec -i "${KAFKA_CONTAINER}" bash -lc \
    "kafka-console-producer --bootstrap-server ${BOOTSTRAP_IN_DOCKER} --topic ${topic} --property parse.key=true --property key.separator=:" \
    <<< "${key}:${json}"
}

kafka_tail() {
  local topic="$1"
  docker exec -it "${KAFKA_CONTAINER}" bash -lc \
    "kafka-console-consumer --bootstrap-server ${BOOTSTRAP_IN_DOCKER} --topic ${topic} --from-beginning --timeout-ms 10000"
}

help() {
  cat <<'EOF'
Souq CLI (bash)

Usage:
  ./scripts/cli/souq.sh help
  ./scripts/cli/souq.sh health

Platform (REST):
  ./scripts/cli/souq.sh platform register-user <userId> <email> <displayName>
Publisher (REST):
  ./scripts/cli/souq.sh publisher publish-game <gameId> <title>

Notifications (REST):
  ./scripts/cli/souq.sh notif get <userId>

Kafka:
  ./scripts/cli/souq.sh kafka tail publisher|platform|notification

Injecter des events platform (Kafka direct):
  ./scripts/cli/souq.sh event purchase <userId> <gameId> [eventId]
  ./scripts/cli/souq.sh event incident <userId> <gameId> <desc> [eventId]
  ./scripts/cli/souq.sh event review <userId> <gameId> <rating> <comment> [eventId]

Env vars:
  PUBLISHER_URL=http://localhost:8082
  NOTIFICATION_URL=http://localhost:8083
  KAFKA_CONTAINER_NAME=kafka
  BOOTSTRAP_IN_DOCKER=kafka:9092
EOF
}

# =========================
# Commands
# =========================
require curl
require docker

cmd="${1:-help}"
sub="${2:-}"

case "${cmd}" in
  help|-h|--help|"")
    help
    ;;

  health)
    echo "Kafka container: ${KAFKA_CONTAINER}"
    echo "Notif health: ${NOTIFICATION_URL}/notifications/health"
    curl -sf "${NOTIFICATION_URL}/notifications/health" && echo
    ;;

  publisher)
    case "${sub}" in
      publish-game)
        gameId="${3:-}"; title="${4:-}"
        [[ -n "${gameId}" && -n "${title}" ]] || die "Usage: publisher publish-game <gameId> <title>"
        curl -s "${PUBLISHER_URL}/publisher/publish-game?gameId=${gameId}&title=${title}"
        echo
        ;;
      *)
        die "Sous-commande publisher inconnue. (attendu: publish-game)"
        ;;
    esac
    ;;

  notif)
    case "${sub}" in
      get)
        userId="${3:-}"
        [[ -n "${userId}" ]] || die "Usage: notif get <userId>"
        curl -s "${NOTIFICATION_URL}/notifications/${userId}"
        echo
        ;;
      *)
        die "Sous-commande notif inconnue. (attendu: get)"
        ;;
    esac
    ;;

  platform)
    case "${sub}" in
      register-user)
        userId="${3:-}"
        email="${4:-}"
        displayName="${5:-}"

        [[ -n "${userId}" && -n "${email}" && -n "${displayName}" ]] || \
          die "Usage: platform register-user <userId> <email> <displayName>"

        # Appel robuste (encodage safe)
        curl -sS --fail --get "${PLATFORM_URL}/platform/users/register" \
          --data-urlencode "userId=${userId}" \
          --data-urlencode "email=${email}" \
          --data-urlencode "displayName=${displayName}"
        echo
        ;;
      *)
        die "Sous-commande platform inconnue (attendu: register-user)"
        ;;
    esac
    ;;

  kafka)
    case "${sub}" in
      tail)
        which="${3:-}"
        [[ -n "${which}" ]] || die "Usage: kafka tail publisher|platform|notification"
        case "${which}" in
          publisher) kafka_tail "${TOPIC_PUBLISHER}" ;;
          platform) kafka_tail "${TOPIC_PLATFORM}" ;;
          notification) kafka_tail "${TOPIC_NOTIFICATION}" ;;
          *) die "Choisis publisher|platform|notification" ;;
        esac
        ;;
      *)
        die "Sous-commande kafka inconnue. (attendu: tail)"
        ;;
    esac
    ;;

  event)
    kind="${sub}"
    ts="$(now_iso)"

    case "${kind}" in
      purchase)
        userId="${3:-}"; gameId="${4:-}"; eventId="${5:-$(uuid)}"
        [[ -n "${userId}" && -n "${gameId}" ]] || die "Usage: event purchase <userId> <gameId> [eventId]"
        json='{"eventId":"'"${eventId}"'","eventType":"GamePurchased","occurredAt":"'"${ts}"'","schemaVersion":1,"payload":{"userId":"'"${userId}"'","gameId":"'"${gameId}"'"}}'
        kafka_produce "${TOPIC_PLATFORM}" "${userId}" "${json}"  # key=userId
        echo "✅ produced GamePurchased eventId=${eventId}"
        ;;

      incident)
        userId="${3:-}"; gameId="${4:-}"; desc="${5:-}"; eventId="${6:-$(uuid)}"
        [[ -n "${userId}" && -n "${gameId}" && -n "${desc}" ]] || die "Usage: event incident <userId> <gameId> <desc> [eventId]"
        # escape double quotes in desc
        desc_escaped="${desc//\"/\\\"}"
        json='{"eventId":"'"${eventId}"'","eventType":"IncidentReported","occurredAt":"'"${ts}"'","schemaVersion":1,"payload":{"userId":"'"${userId}"'","gameId":"'"${gameId}"'","description":"'"${desc_escaped}"'"}}'
        kafka_produce "${TOPIC_PLATFORM}" "${gameId}" "${json}"   # key=gameId
        echo "✅ produced IncidentReported eventId=${eventId}"
        ;;

      review)
        userId="${3:-}"; gameId="${4:-}"; rating="${5:-}"; comment="${6:-}"; eventId="${7:-$(uuid)}"
        [[ -n "${userId}" && -n "${gameId}" && -n "${rating}" && -n "${comment}" ]] || die "Usage: event review <userId> <gameId> <rating> <comment> [eventId]"
        comment_escaped="${comment//\"/\\\"}"
        json='{"eventId":"'"${eventId}"'","eventType":"ReviewSubmitted","occurredAt":"'"${ts}"'","schemaVersion":1,"payload":{"userId":"'"${userId}"'","gameId":"'"${gameId}"'","rating":'"${rating}"',"comment":"'"${comment_escaped}"'"}}'
        kafka_produce "${TOPIC_PLATFORM}" "${gameId}" "${json}"   # key=gameId
        echo "✅ produced ReviewSubmitted eventId=${eventId}"
        ;;

      *)
        die "event inconnu: ${kind} (purchase|incident|review)"
        ;;
    esac
    ;;

  *)
    die "Commande inconnue: ${cmd} (run ./scripts/cli/souq.sh help)"
    ;;
esac