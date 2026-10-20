-- Do a few sellers cause most of the late deliveries? I only list sellers with at least 50
-- delivered orders.
-- One row per order and seller. 1,275 delivered orders have items from more than one seller.
-- Those orders count once for each seller, and if the order was late it counts as late for
-- all of them (checked in 00_grain_checks.sql).

WITH delivered AS (
    SELECT
        order_id,
        order_delivered_carrier_date,
        CASE WHEN date(order_delivered_customer_date) > date(order_estimated_delivery_date)
             THEN 1 ELSE 0 END AS is_late
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
),
order_sellers AS (
    -- One row per order and seller. If a seller has several items in the order, I use the
    -- latest shipping_limit_date as that seller's deadline.
    SELECT order_id, seller_id, MAX(shipping_limit_date) AS shipping_limit
    FROM order_items
    GROUP BY order_id, seller_id
),
seller_orders AS (
    SELECT
        os.seller_id,
        d.is_late,
        CASE WHEN d.order_delivered_carrier_date > os.shipping_limit THEN 1 ELSE 0 END AS shipped_after_limit
    FROM order_sellers os
    JOIN delivered d ON d.order_id = os.order_id
),
seller_stats AS (
    SELECT
        seller_id,
        COUNT(*) AS delivered_orders,
        SUM(is_late) AS late_orders,
        SUM(shipped_after_limit) AS shipped_after_limit_orders
    FROM seller_orders
    GROUP BY seller_id
),
totals AS (
    SELECT SUM(late_orders) AS all_late_seller_orders,
           1.0 * SUM(late_orders) / SUM(delivered_orders) AS platform_late_rate
    FROM seller_stats
)
SELECT
    ROW_NUMBER() OVER (ORDER BY 1.0 * s.late_orders / s.delivered_orders DESC, s.late_orders DESC,
                       s.seller_id) AS late_rate_rank,
    s.seller_id,
    se.seller_state,
    s.delivered_orders,
    s.late_orders,
    ROUND(100.0 * s.late_orders / s.delivered_orders, 1) AS late_rate_pct,
    ROUND(1.0 * s.late_orders / s.delivered_orders / t.platform_late_rate, 2) AS late_rate_vs_platform,
    ROUND(100.0 * s.shipped_after_limit_orders / s.delivered_orders, 1) AS shipped_after_limit_pct,
    -- This share is out of all late seller-orders, so a two-seller order counts twice.
    ROUND(100.0 * s.late_orders / t.all_late_seller_orders, 2) AS share_of_all_late_pct,
    -- Running share of all late seller-orders, worst late rate first.
    ROUND(100.0 * SUM(s.late_orders) OVER (
              ORDER BY 1.0 * s.late_orders / s.delivered_orders DESC, s.late_orders DESC, s.seller_id
              ROWS UNBOUNDED PRECEDING) / t.all_late_seller_orders, 1) AS cumulative_share_of_late_pct
FROM seller_stats s
JOIN sellers se ON se.seller_id = s.seller_id
CROSS JOIN totals t
WHERE s.delivered_orders >= 50
ORDER BY late_rate_rank;
