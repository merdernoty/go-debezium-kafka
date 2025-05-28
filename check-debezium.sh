#!/usr/bin/env bash

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Checking Debezium setup...${NC}"

# Check if PostgreSQL is accessible
echo -e "\n${YELLOW}Checking PostgreSQL connection...${NC}"
if podman exec -it go-debezium-kafka-postgres-1 psql -U user -d userdb -c "SELECT 1" >/dev/null 2>&1; then
  echo -e "${GREEN}✓ PostgreSQL is accessible${NC}"
else
  echo -e "${RED}✗ Cannot connect to PostgreSQL${NC}"
  exit 1
fi

# Check for logical replication settings
echo -e "\n${YELLOW}Checking PostgreSQL replication settings...${NC}"
podman exec -it go-debezium-kafka-postgres-1 psql -U user -d userdb -c "SHOW wal_level;"
podman exec -it go-debezium-kafka-postgres-1 psql -U user -d userdb -c "SHOW max_replication_slots;"
podman exec -it go-debezium-kafka-postgres-1 psql -U user -d userdb -c "SHOW max_wal_senders;"

# Check if the publication exists
echo -e "\n${YELLOW}Checking PostgreSQL publication...${NC}"
PUBLICATION_COUNT=$(podman exec -it go-debezium-kafka-postgres-1 psql -U user -d userdb -t -c "SELECT COUNT(*) FROM pg_publication WHERE pubname = 'dbserver1_pub';")
if [[ $PUBLICATION_COUNT -gt 0 ]]; then
  echo -e "${GREEN}✓ Publication 'dbserver1_pub' exists${NC}"
  podman exec -it go-debezium-kafka-postgres-1 psql -U user -d userdb -c "SELECT * FROM pg_publication;"
  podman exec -it go-debezium-kafka-postgres-1 psql -U user -d userdb -c "SELECT * FROM pg_publication_tables WHERE pubname = 'dbserver1_pub';"
else
  echo -e "${RED}✗ Publication 'dbserver1_pub' does not exist${NC}"
fi

# Check if the replication slot exists
echo -e "\n${YELLOW}Checking PostgreSQL replication slot...${NC}"
SLOT_COUNT=$(podman exec -it go-debezium-kafka-postgres-1 psql -U user -d userdb -t -c "SELECT COUNT(*) FROM pg_replication_slots WHERE slot_name = 'debezium_slot';")
if [[ $SLOT_COUNT -gt 0 ]]; then
  echo -e "${GREEN}✓ Replication slot 'debezium_slot' exists${NC}"
  podman exec -it go-debezium-kafka-postgres-1 psql -U user -d userdb -c "SELECT * FROM pg_replication_slots WHERE slot_name = 'debezium_slot';"
else
  echo -e "${RED}✗ Replication slot 'debezium_slot' does not exist${NC}"
fi

# Check Kafka Connect status
echo -e "\n${YELLOW}Checking Kafka Connect status...${NC}"
CONNECT_STATUS=$(curl -s http://localhost:8083/ | grep -o "Kafka Connect")
if [[ $CONNECT_STATUS == "Kafka Connect" ]]; then
  echo -e "${GREEN}✓ Kafka Connect is running${NC}"
else
  echo -e "${RED}✗ Kafka Connect is not accessible${NC}"
fi

# Check connector status
echo -e "\n${YELLOW}Checking connector status...${NC}"
CONNECTOR_STATUS=$(curl -s http://localhost:8083/connectors/user-connector/status)
if [[ $CONNECTOR_STATUS != *"error"* ]]; then
  echo -e "${GREEN}✓ Connector 'user-connector' is configured${NC}"
  echo "$CONNECTOR_STATUS"
else
  echo -e "${RED}✗ Connector 'user-connector' is not configured or has errors${NC}"
  echo "$CONNECTOR_STATUS"
fi

# Check Kafka topics
echo -e "\n${YELLOW}Checking Kafka topics...${NC}"
podman exec -it go-debezium-kafka-kafka-1 kafka-topics --bootstrap-server=kafka:9092 --list

echo -e "\n${YELLOW}Checking CDC topic data...${NC}"
podman exec -it go-debezium-kafka-kafka-1 kafka-console-consumer --bootstrap-server=kafka:9092 --topic dbserver1.public.users --from-beginning --max-messages 5

echo -e "\n${GREEN}Check complete!${NC}"