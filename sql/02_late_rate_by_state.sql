-- 02. Which customer states have the highest late-delivery rates?
-- Scope: delivered orders with a delivery date (96,470 orders).
-- Grain: one row per order. customers has one row per customer_id (primary key) and
-- latest_review one row per order, so both joins keep 96,470 rows (see 00_grain_checks.sql).

WITH delivered AS (
    SELECT
        order_id,
        customer_id,
        order_purchase_timestamp,
        order_delivered_customer_date,
        order_estimated_delivery_date,
        CASE WHEN date(order_delivered_customer_date) > date(order_estimated_delivery_date)
             THEN 1 ELSE 0 END AS is_late
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
),
latest_review AS (
    SELECT order_id, review_score
    FROM (
        SELECT order_id, review_score,
               ROW_NUMBER() OVER (PARTITION BY order_id
                                  ORDER BY review_answer_timestamp DESC, review_id) AS rn
        FROM order_reviews
    )
    WHERE rn = 1
)
SELECT
    c.customer_state,
    CASE
        WHEN c.customer_state IN ('AC','AP','AM','PA','RO','RR','TO') THEN 'North'
        WHEN c.customer_state IN ('AL','BA','CE','MA','PB','PE','PI','RN','SE') THEN 'Northeast'
        WHEN c.customer_state IN ('DF','GO','MT','MS') THEN 'Central-West'
        WHEN c.customer_state IN ('ES','MG','RJ','SP') THEN 'Southeast'
        WHEN c.customer_state IN ('PR','RS','SC') THEN 'South'
    END AS customer_region,
    COUNT(*) AS delivered_orders,
    SUM(d.is_late) AS late_orders,
    ROUND(100.0 * AVG(d.is_late), 1) AS late_rate_pct,
    ROUND(100.0 * SUM(d.is_late) / SUM(SUM(d.is_late)) OVER (), 1) AS share_of_all_late_pct,
    ROUND(AVG(julianday(d.order_delivered_customer_date)
              - julianday(d.order_purchase_timestamp)), 1) AS avg_days_to_deliver,
    ROUND(AVG(julianday(d.order_estimated_delivery_date)
              - julianday(d.order_purchase_timestamp)), 1) AS avg_days_promised,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM delivered d
JOIN customers c ON c.customer_id = d.customer_id
LEFT JOIN latest_review r ON r.order_id = d.order_id
GROUP BY c.customer_state
ORDER BY late_rate_pct DESC;
