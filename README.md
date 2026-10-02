# EverMade Bank

Учебный стенд нагрузочного тестирования: мини-банк с REST API,
асинхронной обработкой транзакций через Kafka, полноценным UI
и стеком мониторинга Prometheus + Grafana.

---

## Быстрый старт

    make up        # собрать и запустить всё
    make smoke     # проверить, что API живой
    make urls      # все адреса и учётки

Остановить / сбросить:

    make down          # остановить контейнеры (данные сохраняются)
    make clean         # удалить всё включая volumes
    make reset-db      # пересоздать Postgres
    make reset-kafka   # сбросить offset consumer group

---

## Точки входа

| Сервис         | URL / адрес                                       | Учётки                |
|----------------|---------------------------------------------------|-----------------------|
| UI             | http://localhost:2010                             | alice/alice, bob/bob  |
| API (Swagger)  | http://localhost:2020/docs                        | —                     |
| PostgreSQL     | localhost:2030                                    | evermade / evermade   |
| Kafka          | localhost:2040                                    | —                     |
| Prometheus     | http://localhost:2050                             | —                     |
| Grafana        | http://localhost:2060                             | admin / admin         |
| Kafka exporter | http://localhost:2070/metrics                     | —                     |
| cAdvisor       | http://localhost:2080                             | —                     |
| PG exporter    | http://localhost:2090/metrics                     | —                     |

---

## Тестовые пользователи

| Логин | Пароль | ФИО             | Счёт                | Баланс   |
|-------|--------|-----------------|---------------------|----------|
| alice | alice  | Alice Ivanova   | 4081781000000001    | 10 000 ₽ |
| bob   | bob    | Bob Petrov      | 4081781000000002    |  5 000 ₽ |
| carol | carol  | Carol Sidorova  | 4081781000000003    | 15 000 ₽ |

---

## Что умеет приложение

- Регистрация — POST /register (открытая, автосоздаёт счёт на 10 000 ₽).
- Логин / логаут — Bearer-токен в localStorage браузера, TTL 24 часа.
- Открытие счёта — POST /accounts, номер генерируется 16-значный (40817XXXXXXXXXXX).
- Перевод по номеру счёта — POST /transfer, асинхронная обработка через Kafka.
- История транзакций — GET /transactions (вход + исход).
- Уведомления — GET /notifications (входящие DONE-переводы).
- Ставка по кредиту — GET /loan/rate (случайная 10.00–15.55%).

---

## Внешние инструменты

DBeaver (PostgreSQL):
  Host: localhost, Port: 2030, DB: evermade_bank
  User: evermade, Password: evermade

Offset Explorer (Kafka):
  Bootstrap: localhost:2040
  Topic: transactions

JMeter:
  Base URL: http://localhost:2020 (напрямую в API)
  Готовый план: jmeter/banking-test.jmx

---

## Grafana — 4 дашборда (папка EverMade Bank)

1. Overview      — RPS, latency p50/p95/p99, tx produced vs processed, Kafka lag,
                   логины, регистрации, loan rate.
2. Containers    — CPU/RAM/net/disk по каждому контейнеру (cAdvisor).
3. Postgres      — connections, xact rate, locks, cache hit ratio.
4. Kafka         — brokers, consumer lag, throughput, partitions.

---

## Типовые узкие места

1. Пул соединений к Postgres (asyncpg max_size=10) — при росте RPS очередь растёт.
2. Конкуренция за строки (SELECT ... FOR UPDATE в worker'е) — параллельные
   переводы на один счёт сериализуются.
3. Kafka consumer lag — producer быстрее consumer'а, сообщения копятся в топике.
4. Один partition топика transactions — масштабирование ограничено.
5. CPU throttling контейнеров под нагрузкой (видно в Containers dashboard).

---

## Полезные команды

    make urls          # все адреса
    make ps            # статус контейнеров
    make logs          # логи всех сервисов
    make kafka-topics  # список топиков
    make kafka-lag     # состояние consumer group
    make reset-db      # пересоздать Postgres
    make reset-kafka   # сбросить offset
    make clean         # снести всё

---

## Стек

- API:       FastAPI (Python 3.12), Bearer-токены, asyncpg, aiokafka
- Worker:    asyncpg + aiokafka, ручной commit, graceful shutdown
- UI:        nginx + vanilla JS SPA (hash-роутер), тёмная тема
- DB:        PostgreSQL 16
- Broker:    Apache Kafka 3.7.1 (KRaft, single-node)
- Metrics:   Prometheus 2.54, cAdvisor 0.49, postgres-exporter 0.16,
             kafka-exporter 1.7
- Grafana:   11.2 с provisioned datasource и 4 дашбордами

---

## Архитектура

    UI (nginx) --> API (FastAPI) --> Postgres
                       |
                       v
                  Kafka topic: transactions
                       |
                       v
                  Worker (async consumer)
                       |
                       v
                  Postgres (balance update)

    Prometheus  <-- api:/metrics, worker:/metrics,
                    cadvisor, postgres-exporter, kafka-exporter
                       |
                       v
                  Grafana (4 dashboards)
