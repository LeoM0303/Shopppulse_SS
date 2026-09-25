-- Fixture rows so the trainee SELECT session has something to return.
-- Safe to re-run: the ids are fixed.

INSERT INTO sales_events (
    id, store_id, product_id, product_name, event_type, quantity, unit_price, occurred_at, created_at
) VALUES
    ('11111111-1111-1111-1111-111111111111', 'store-42', 'SKU-9981', 'Widget Pro', 'sale', 2, 49.99, NOW() - INTERVAL '1 hour', NOW()),
    ('22222222-2222-2222-2222-222222222222', 'store-42', 'SKU-9981', 'Widget Pro', 'return', 1, 49.99, NOW() - INTERVAL '50 minutes', NOW()),
    ('33333333-3333-3333-3333-333333333333', 'store-7', 'SKU-1001', 'Gadget Mini', 'sale', 5, 9.50, NOW() - INTERVAL '30 minutes', NOW())
ON CONFLICT (id) DO NOTHING;
