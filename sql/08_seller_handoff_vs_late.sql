-- 08. Are late deliveries caused by sellers shipping late or by time in transit?
-- Scope: delivered orders with a delivery date. "Handed over late" = the carrier pickup
-- date is after the seller's shipping deadline. For orders with several items or sellers,
-- the deadline is the latest shipping_limit_date in the order, which gives sellers the
-- benefit of the doubt.
-- Grain: order_deadlines groups order_items by order_id, so it has one row per order (the
-- same grouping as order_totals in 00_grain_checks.sql) and the join keeps 96,470 rows.

WITH delivered AS (
    SELECT
        order_id,
        order_purchase_timestamp,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        CASE WHEN date(order_delivered_customer_date) > date(order_estimated_delivery_date)
             THEN 1 ELSE 0 END AS is_late
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
),
order_deadlines AS (
    SELECT order_id, MAX(shipping_limit_date) AS shipping_limit
    FROM order_items
    GROUP BY order_id
),
classified AS (
    SELECT
        d.*,
        CASE
            WHEN d.order_delivered_carrier_date IS NULL THEN 'No carrier date'
            WHEN d.order_delivered_carrier_date > od.shipping_limit THEN 'Handed over late'
            ELSE 'Handed over on time'
        END AS handoff_status
    FROM delivered d
    JOIN order_deadlines od ON od.order_id = d.order_id
)
SELECT
    handoff_status,
    COUNT(*) AS orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_of_orders_pct,
    SUM(is_late) AS late_orders,
    ROUND(100.0 * AVG(is_late), 1) AS late_rate_pct,
    ROUND(100.0 * SUM(is_late) / SUM(SUM(is_late)) OVER (), 1) AS share_of_all_late_pct,
    ROUND(AVG(julianday(order_delivered_carrier_date) - julianday(order_purchase_timestamp)), 1)
        AS avg_days_purchase_to_carrier,
    ROUND(AVG(julianday(order_delivered_customer_date) - julianday(order_delivered_carrier_date)), 1)
        AS avg_days_carrier_to_customer
FROM classified
GROUP BY handoff_status
ORDER BY orders DESC;
