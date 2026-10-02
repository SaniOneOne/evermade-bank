-- ============================================================
-- EverMade Bank — схема БД
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Пользователи
CREATE TABLE IF NOT EXISTS users (
    id          SERIAL PRIMARY KEY,
    username    VARCHAR(50)  UNIQUE NOT NULL,
    password    VARCHAR(100) NOT NULL,
    full_name   VARCHAR(100) NOT NULL,
    created_at  TIMESTAMPTZ  DEFAULT NOW()
);

-- Сессии (Bearer-токены)
CREATE TABLE IF NOT EXISTS sessions (
    token       VARCHAR(64)  PRIMARY KEY,
    user_id     INT          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ  DEFAULT NOW(),
    expires_at  TIMESTAMPTZ  NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);

-- Счета (16-значный номер, у каждого пользователя может быть много)
CREATE TABLE IF NOT EXISTS accounts (
    id             SERIAL PRIMARY KEY,
    user_id        INT          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    account_number VARCHAR(16)  UNIQUE NOT NULL,
    balance        NUMERIC(14,2) NOT NULL DEFAULT 0,
    currency       VARCHAR(3)   NOT NULL DEFAULT 'RUB',
    created_at     TIMESTAMPTZ  DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_accounts_user    ON accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_accounts_number  ON accounts(account_number);

-- Транзакции
-- FK на accounts — ON DELETE SET NULL, чтобы счёт можно было физически удалить,
-- а история транзакций сохранилась. Снимки номеров и ФИО храним прямо тут.
CREATE TABLE IF NOT EXISTS transactions (
    id                   BIGSERIAL PRIMARY KEY,
    from_account_id      INT REFERENCES accounts(id) ON DELETE SET NULL,
    to_account_id        INT REFERENCES accounts(id) ON DELETE SET NULL,
    from_account_number  VARCHAR(16),
    to_account_number    VARCHAR(16),
    from_name            VARCHAR(100),
    to_name              VARCHAR(100),
    amount               NUMERIC(14,2) NOT NULL,
    status               VARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    created_at           TIMESTAMPTZ   DEFAULT NOW(),
    processed_at         TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_tx_status   ON transactions(status);
CREATE INDEX IF NOT EXISTS idx_tx_created  ON transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_tx_from     ON transactions(from_account_id);
CREATE INDEX IF NOT EXISTS idx_tx_to       ON transactions(to_account_id);

-- Ставки по кредитам
CREATE TABLE IF NOT EXISTS loan_rates (
    id          BIGSERIAL PRIMARY KEY,
    user_id     INT          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rate        NUMERIC(5,2) NOT NULL,
    created_at  TIMESTAMPTZ  DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_loan_user ON loan_rates(user_id);

-- ============================================================
-- Сид-данные
-- ============================================================

INSERT INTO users (username, password, full_name) VALUES
    ('alice', 'alice', 'Alice Ivanova'),
    ('bob',   'bob',   'Bob Petrov'),
    ('carol', 'carol', 'Carol Sidorova')
ON CONFLICT (username) DO NOTHING;

INSERT INTO accounts (user_id, account_number, balance, currency) VALUES
    (1, '4081781000000001', 10000.00, 'RUB'),
    (2, '4081781000000002',  5000.00, 'RUB'),
    (3, '4081781000000003', 15000.00, 'RUB')
ON CONFLICT (account_number) DO NOTHING;
