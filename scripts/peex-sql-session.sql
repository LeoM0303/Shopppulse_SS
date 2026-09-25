-- Trainee PEEX artifact: a real database client session, not application code.
-- Run against a live PostgreSQL 16 (compose, CI service, or a jump pod).
--
--   PGPASSWORD=localdev psql -h localhost -U shoppulse -d shoppulse \
--     -v ON_ERROR_STOP=1 -f scripts/peex-sql-session.sql

\conninfo
\echo === engine version ===
SELECT version();
SELECT current_setting('server_version') AS server_version,
       current_setting('server_version_num') AS server_version_num;

\echo === session identity ===
SELECT current_user, current_database(), inet_server_addr(), inet_server_port();

\echo === schema ===
\dt
\d sales_events

\echo === DQL: last 24 hours, grouped by product ===
SELECT
    product_id,
    MAX(product_name) AS product_name,
    SUM(CASE WHEN event_type = 'sale' THEN quantity ELSE 0 END) AS units_sold,
    SUM(
        CASE WHEN event_type = 'sale' THEN unit_price * quantity
             WHEN event_type = 'return' THEN -(unit_price * quantity)
             ELSE 0 END
    ) AS revenue
FROM sales_events
WHERE occurred_at >= NOW() - INTERVAL '24 hours'
GROUP BY product_id
ORDER BY units_sold DESC
LIMIT 10;

\echo === DQL: stores with a return rate above 10% ===
SELECT
    store_id,
    SUM(CASE WHEN event_type = 'return' THEN 1 ELSE 0 END)::float
        / NULLIF(COUNT(*), 0) AS return_rate
FROM sales_events
WHERE occurred_at >= NOW() - INTERVAL '24 hours'
GROUP BY store_id
HAVING SUM(CASE WHEN event_type = 'return' THEN 1 ELSE 0 END)::float
         / NULLIF(COUNT(*), 0) > 0.1;
