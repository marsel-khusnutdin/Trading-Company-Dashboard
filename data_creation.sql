-- =========================================================
-- Deterministic random-looking demo data
-- PostgreSQL + 3 schemas (db_default, db_transaction, db_orderstat)
-- =========================================================

-- Clean up schemas for re-runs
DROP SCHEMA IF EXISTS db_orderstat CASCADE;
DROP SCHEMA IF EXISTS db_transaction CASCADE;
DROP SCHEMA IF EXISTS db_default CASCADE;

CREATE SCHEMA db_default;
CREATE SCHEMA db_transaction;
CREATE SCHEMA db_orderstat;

-- =========================================================
-- 1. Table definitions
-- =========================================================

CREATE TABLE db_default.tb_users (
    uid               INTEGER PRIMARY KEY,
    registration_date DATE NOT NULL,
    country           TEXT NOT NULL
);

CREATE TABLE db_default.tb_logins (
    login        TEXT PRIMARY KEY,
    user_uid     INTEGER NOT NULL REFERENCES db_default.tb_users(uid),
    account_type TEXT NOT NULL CHECK (account_type IN ('real','demo'))
);

CREATE TABLE db_transaction.tb_operations (
    id             SERIAL PRIMARY KEY,
    operation_type TEXT NOT NULL CHECK (operation_type IN ('deposit','withdrawal')),
    operation_date DATE NOT NULL,
    login          TEXT NOT NULL REFERENCES db_default.tb_logins(login),
    amount         NUMERIC(12,2) NOT NULL  -- USD
);

CREATE TABLE db_orderstat.tb_orders (
    id               SERIAL PRIMARY KEY,
    login            TEXT NOT NULL REFERENCES db_default.tb_logins(login),
    order_open_date  TIMESTAMP NOT NULL,
    order_close_date TIMESTAMP,
    volume_usd       NUMERIC(14,2) NOT NULL
);

-- =========================================================
-- 2. Deterministic random seed (for dates, amounts, etc.)
-- =========================================================
SELECT setseed(0.42);

-- =========================================================
-- 3. Users: 1200 users, 12 full country names
--    Country assignment via hash(uid) → "random-looking" but stable
-- =========================================================

WITH countries AS (
    SELECT
        ROW_NUMBER() OVER () AS idx,
        country
    FROM unnest(ARRAY[
        'Cyprus',
        'Germany',
        'United Kingdom',
        'Netherlands',
        'Spain',
        'Italy',
        'France',
        'Poland',
        'Lithuania',
        'Greece',
        'Portugal',
        'Ireland'
    ]) AS country
),
user_ids AS (
    SELECT generate_series(1, 1200) AS uid   -- <<< 1200 USERS
)
INSERT INTO db_default.tb_users (uid, registration_date, country)
SELECT
    u.uid,
    DATE '2024-01-01' + (trunc(random() * 365)::int) AS registration_date,
    (
        SELECT c.country
        FROM countries c
        WHERE c.idx = (abs(hashtext(u.uid::text)) % 12) + 1
    ) AS country
FROM user_ids u
ORDER BY u.uid;

-- =========================================================
-- 4. Logins: 1–3 accounts per user (real & demo)
-- =========================================================

WITH expanded AS (
    SELECT
        u.uid AS user_uid,
        gs.idx,
        CASE WHEN random() < 0.7 THEN 'real' ELSE 'demo' END AS account_type
    FROM db_default.tb_users u
    CROSS JOIN LATERAL (
        VALUES (1), (2), (3)
    ) AS gs(idx)
    WHERE
        gs.idx = 1
        OR (gs.idx = 2 AND random() < 0.6)  -- ~60% get a 2nd login
        OR (gs.idx = 3 AND random() < 0.3)  -- ~30% get a 3rd login
),
numbered AS (
    SELECT
        user_uid,
        account_type,
        ROW_NUMBER() OVER (ORDER BY user_uid, idx) AS rn
    FROM expanded
)
INSERT INTO db_default.tb_logins (login, user_uid, account_type)
SELECT
    'L' || to_char(100000 + rn, 'FM000000') AS login,
    user_uid,
    account_type
FROM numbered
ORDER BY rn;

-- =========================================================
-- 5. Mark which users deposit and trade (deterministic rules)
--    - Users with uid % 4 <> 0 → depositors (~75% of all)
--    - Among those, uid % 5 <> 0 → traders (~80% of depositors)
-- =========================================================

CREATE TEMP TABLE tmp_deposit_logins AS
SELECT
    l.login,
    l.user_uid,
    u.registration_date
FROM db_default.tb_logins l
JOIN db_default.tb_users u ON u.uid = l.user_uid
WHERE (u.uid % 4) <> 0;   -- 3 out of 4 users → 75% depositors

CREATE TEMP TABLE tmp_trading_logins AS
SELECT
    dl.login,
    dl.user_uid,
    dl.registration_date
FROM tmp_deposit_logins dl
JOIN db_default.tb_users u ON u.uid = dl.user_uid
WHERE (u.uid % 5) <> 0;   -- ~80% of depositors → traders

-- =========================================================
-- 6. Operations: deposits & withdrawals
--    - Every deposit-login gets at least 1 deposit
--    - First deposit: within 30 days after registration
--    - Extra random deposits & withdrawals
--    - USD amounts with some outliers
-- =========================================================

WITH deposit1 AS (
    -- One guaranteed deposit per deposit login
    -- First deposit: 1–30 days after registration_date
    SELECT
        dl.login,
        dl.registration_date + (1 + trunc(random() * 29)::int) AS operation_date,  -- 1..30 days
        ROUND((
            CASE
                WHEN random() < 0.90
                    THEN 50 + random() * 2950      -- 50 .. 3000 (typical)
                ELSE 5000 + random() * 25000       -- 5000 .. 30000 (outliers)
            END
        )::numeric, 2) AS amount
    FROM tmp_deposit_logins dl
),
deposit_extra AS (
    -- 0–3 extra deposits per login, anywhere later in time
    SELECT
        dl.login,
        dl.registration_date + (5 + trunc(random() * 180)::int) AS operation_date,
        ROUND((
            CASE
                WHEN random() < 0.90
                    THEN 50 + random() * 2950
                ELSE 5000 + random() * 25000
            END
        )::numeric, 2) AS amount
    FROM tmp_deposit_logins dl
    CROSS JOIN LATERAL generate_series(1, 3) AS gs(n)
    WHERE random() < 0.4
),
withdrawals AS (
    -- 0–3 withdrawals per deposit login, negative amounts
    SELECT
        dl.login,
        dl.registration_date + (10 + trunc(random() * 200)::int) AS operation_date,
        ROUND(
            (-(20 + random() * 1980))::numeric   -- -20 .. -2000
        , 2) AS amount
    FROM tmp_deposit_logins dl
    CROSS JOIN LATERAL generate_series(1, 3) AS gs(n)
    WHERE random() < 0.5
),
all_ops AS (
    SELECT 'deposit' AS operation_type, operation_date, login, amount FROM deposit1
    UNION ALL
    SELECT 'deposit' AS operation_type, operation_date, login, amount FROM deposit_extra
    UNION ALL
    SELECT 'withdrawal' AS operation_type, operation_date, login, amount FROM withdrawals
)
INSERT INTO db_transaction.tb_operations (operation_type, operation_date, login, amount)
SELECT operation_type, operation_date, login, amount
FROM all_ops
ORDER BY operation_date, login;

-- =========================================================
-- 7. Orders: trades for ~80% of depositors
--    - Each trading login gets 1–6 orders
--    - First trade comes within 40 days after first deposit date
--    - 2% of trades remain open
-- =========================================================

-- First deposit date per login
WITH first_deposit AS (
    SELECT
        login,
        MIN(operation_date) AS first_deposit_date
    FROM db_transaction.tb_operations
    WHERE operation_type = 'deposit'
    GROUP BY login
),
orders_raw AS (
    SELECT
        tl.login,
        fd.first_deposit_date,
        (
            fd.first_deposit_date
            + (1 + trunc(random() * 39)::int)           -- 1..40 days after first deposit
        )::timestamp
        + (trunc(random() * 24)::int || ' hours')::interval
        + (trunc(random() * 60)::int || ' minutes')::interval AS open_dt,
        ROUND((
            CASE
                WHEN random() < 0.90
                    THEN 100 + random() * 4900         -- 100 .. 5000
                ELSE 10000 + random() * 40000          -- 10000 .. 50000 (outliers)
            END
        )::numeric, 2) AS volume_usd,
        random() AS r_close
    FROM tmp_trading_logins tl
    JOIN first_deposit fd ON fd.login = tl.login
    CROSS JOIN LATERAL generate_series(1, 1 + trunc(random() * 5)::int) AS gs(n)
),
orders_w_close AS (
    SELECT
        login,
        open_dt,
        CASE
            WHEN r_close < 0.02                      -- <<< 2% of trades stay open
                THEN NULL::timestamp
            ELSE open_dt + ((1 + trunc(random() * 5)::int) || ' days')::interval
        END AS close_dt,
        volume_usd
    FROM orders_raw
)
INSERT INTO db_orderstat.tb_orders (login, order_open_date, order_close_date, volume_usd)
SELECT
    login,
    open_dt,
    close_dt,
    volume_usd
FROM orders_w_close
ORDER BY open_dt, login;

-- =========================================================
-- 8. Optional quick checks (uncomment to inspect)
-- =========================================================
-- SELECT COUNT(*) AS total_users FROM db_default.tb_users;
-- SELECT country, COUNT(*) AS users_per_country
-- FROM db_default.tb_users
-- GROUP BY country
-- ORDER BY users_per_country DESC;
--
-- SELECT COUNT(DISTINCT user_uid) AS users_with_deposits
-- FROM db_default.tb_logins l
-- JOIN db_transaction.tb_operations o ON o.login = l.login
-- WHERE o.operation_type = 'deposit';
--
-- SELECT COUNT(DISTINCT user_uid) AS users_with_trades
-- FROM db_default.tb_logins l
-- JOIN db_orderstat.tb_orders od ON od.login = l.login;
--
-- -- Check first deposit & first trade gap:
-- SELECT
--   l.user_uid,
--   MIN(o.operation_date) AS first_deposit_date,
--   MIN(t.order_open_date) AS first_trade_date,
--   (MIN(t.order_open_date) - MIN(o.operation_date)) AS diff
-- FROM db_default.tb_logins l
-- JOIN db_transaction.tb_operations o ON o.login = l.login AND o.operation_type='deposit'
-- JOIN db_orderstat.tb_orders t ON t.login = l.login
-- GROUP BY l.user_uid
-- LIMIT 20;
