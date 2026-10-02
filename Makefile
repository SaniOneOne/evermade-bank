include .env
export

.PHONY: up down build restart logs ps smoke urls reset-db reset-kafka clean kafka-topics kafka-lag

up:
	docker compose up -d --build

down:
	docker compose down

build:
	docker compose build

restart:
	docker compose restart

logs:
	docker compose logs -f --tail=100

ps:
	docker compose ps

smoke:
	@echo "-> health"
	@curl -s http://localhost:$(API_PORT)/health && echo
	@echo "-> register test user"
	@curl -s -X POST http://localhost:$(API_PORT)/register -H "Content-Type: application/json" -d '{"username":"smoke_user","password":"smoke","full_name":"Smoke Test"}' && echo
	@echo "-> login alice"
	@curl -s -X POST http://localhost:$(API_PORT)/login -H "Content-Type: application/json" -d '{"username":"alice","password":"alice"}' && echo

urls:
	@echo "UI             -> http://localhost:$(UI_PORT)"
	@echo "API (Swagger)  -> http://localhost:$(API_PORT)/docs"
	@echo "PostgreSQL     -> localhost:$(PG_PORT) (evermade/evermade/evermade_bank)"
	@echo "Kafka          -> localhost:$(KAFKA_PORT)"
	@echo "Prometheus     -> http://localhost:$(PROM_PORT)"
	@echo "Grafana        -> http://localhost:$(GRAFANA_PORT) (admin/admin)"
	@echo "Kafka exporter -> http://localhost:$(KAFKA_EXPORTER_PORT)/metrics"
	@echo "cAdvisor       -> http://localhost:$(CADVISOR_PORT)"
	@echo "PG exporter    -> http://localhost:$(PG_EXPORTER_PORT)/metrics"

reset-db:
	docker compose stop api worker
	docker compose rm -f -v postgres
	docker compose up -d postgres
	@sleep 8
	docker compose up -d api worker

reset-kafka:
	docker compose stop worker
	@sleep 3
	docker exec emb-kafka /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group emb-worker --topic transactions --reset-offsets --to-earliest --execute || true
	docker compose start worker

kafka-topics:
	docker exec emb-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list

kafka-lag:
	docker exec emb-kafka /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group emb-worker

clean:
	docker compose down -v --remove-orphans
