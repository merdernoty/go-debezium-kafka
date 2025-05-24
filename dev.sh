#!/usr/bin/env bash

# 1) Поднимаем инфра (Kafka, ZK, Postgres, Debezium)
podman compose up -d

# 2) Ждём, что Postgres и Kafka готовы (можно убрать или увеличить паузу)
echo "⏳ Ждём 5 секунд, пока стартует Postgres и Kafka..."
sleep 5

# 3) Экспортируем переменные окружения для user-service
export DB_DSN="postgres://user:pass@localhost:5432/userdb?sslmode=disable"

# 4) Запускаем user-service локально с hot-reload
(
  cd user-service
  air -c .air.toml
) &

# 5) Запускаем order-service локально с hot-reload
(
  cd order-service
  export KAFKA_BROKERS="localhost:9092"
  export CDC_TOPIC="dbserver1.public.users"
  export GROUP_ID="order-group"
  air -c .air.toml
) &

echo "🚀 Dev готов:
 • http://localhost:8001 — user-service
 • http://localhost:8002 — order-service
 • http://localhost:8083 — Kafka Connect"
