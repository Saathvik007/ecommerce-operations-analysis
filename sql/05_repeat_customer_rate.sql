-- 05. What share of customers order again, and does a late first order change that?
-- Scope: delivered orders with a delivery date. A customer is a customer_unique_id; the
-- source issues a new customer_id for every order, so customer_id cannot identify repeats.
-- Grain: delivered JOIN customers keeps one row per order (96,470). customer_orders then
-- collapses to one row per customer (93,350), and its order counts sum back to 96,470
-- (see 00_grain_checks.sql).

WITH delivered AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        o.order_purchase_timestamp,
        CASE WHEN date(o.order_delivered_customer_date) > date(o.order_estimated_delivery_date)
             THEN 1 ELSE 0 END AS is_late
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY customer_unique_id
                              ORDER BY order_purchase_timestamp, order_id) AS order_number
    FROM delivered
),
customer_orders AS (
    SELECT
        customer_unique_id,
        COUNT(*) AS orders,
        MAX(CASE WHEN order_number = 1 THEN is_late END) AS first_order_late
    FROM ranked
    GROUP BY customer_unique_id
)
SELECT
    'All customers' AS segment,
    COUNT(*) AS customers,
    SUM(orders >= 2) AS repeat_customers,
    ROUND(100.0 * AVG(orders >= 2), 2) AS repeat_rate_pct,
    SUM(orders) AS orders,
    ROUND(1.0 * SUM(orders) / COUNT(*), 3) AS orders_per_customer
FROM customer_orders

UNION ALL

SELECT
    CASE WHEN first_order_late = 1 THEN 'First order late' ELSE 'First order on time' END,
    COUNT(*),
    SUM(orders >= 2),
    ROUND(100.0 * AVG(orders >= 2), 2),
    SUM(orders),
    ROUND(1.0 * SUM(orders) / COUNT(*), 3)
FROM customer_orders
GROUP BY first_order_late;
