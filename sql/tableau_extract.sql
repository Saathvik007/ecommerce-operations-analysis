-- Summary table for the Tableau dashboard. Delivered orders are grouped by month, state,
-- delay bucket and seller handoff status. I only store counts and sums, so the dashboard
-- works out the rates and averages itself and they stay right with any filter:
--   late rate        = SUM(late_orders) / SUM(orders)
--   avg review score = SUM(review_score_sum) / SUM(reviewed_orders)
-- The definitions are the same as in queries 01, 02, 07 and 08. Every delivered order is in
-- here, and the monthly chart filters to January 2017 to August 2018 like query 07.
-- SUM(orders) over the whole extract should be 96,470 delivered orders (run_all.sql checks this).

WITH delivered AS (
    SELECT
        o.order_id,
        o.customer_id,
        substr(o.order_purchase_timestamp, 1, 7) || '-01' AS purchase_month,
        o.order_delivered_carrier_date,
        CAST(julianday(date(o.order_delivered_customer_date))
             - julianday(date(o.order_estimated_delivery_date)) AS INTEGER) AS days_vs_estimate
    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
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
),
order_totals AS (
    SELECT order_id,
           SUM(price) AS revenue,
           SUM(freight_value) AS freight,
           MAX(shipping_limit_date) AS shipping_limit
    FROM order_items
    GROUP BY order_id
),
order_rows AS (
    -- One row per delivered order. Every table joined here also has one row per order.
    SELECT
        d.purchase_month,
        c.customer_state,
        CASE
            WHEN c.customer_state IN ('AC','AP','AM','PA','RO','RR','TO') THEN 'North'
            WHEN c.customer_state IN ('AL','BA','CE','MA','PB','PE','PI','RN','SE') THEN 'Northeast'
            WHEN c.customer_state IN ('DF','GO','MT','MS') THEN 'Central-West'
            WHEN c.customer_state IN ('ES','MG','RJ','SP') THEN 'Southeast'
            WHEN c.customer_state IN ('PR','RS','SC') THEN 'South'
        END AS customer_region,
        CASE
            WHEN d.days_vs_estimate <= 0 THEN 1
            WHEN d.days_vs_estimate <= 3 THEN 2
            WHEN d.days_vs_estimate <= 7 THEN 3
            WHEN d.days_vs_estimate <= 14 THEN 4
            ELSE 5
        END AS bucket_order,
        CASE
            WHEN d.order_delivered_carrier_date IS NULL THEN 'No carrier date'
            WHEN d.order_delivered_carrier_date > t.shipping_limit THEN 'Handed over late'
            ELSE 'Handed over on time'
        END AS handoff_status,
        CASE WHEN d.days_vs_estimate > 0 THEN 1 ELSE 0 END AS is_late,
        r.review_score,
        t.revenue,
        t.freight
    FROM delivered d
    JOIN customers c ON c.customer_id = d.customer_id
    JOIN order_totals t ON t.order_id = d.order_id
    LEFT JOIN latest_review r ON r.order_id = d.order_id
)
SELECT
    purchase_month,
    CAST(substr(purchase_month, 1, 4) AS INTEGER) AS purchase_year,
    customer_state,
    customer_region,
    bucket_order,
    CASE bucket_order
        WHEN 1 THEN 'On time or early'
        WHEN 2 THEN '1-3 days late'
        WHEN 3 THEN '4-7 days late'
        WHEN 4 THEN '8-14 days late'
        ELSE '15+ days late'
    END AS delay_bucket,
    handoff_status,
    COUNT(*) AS orders,
    SUM(is_late) AS late_orders,
    COUNT(review_score) AS reviewed_orders,
    COALESCE(SUM(review_score), 0) AS review_score_sum,
    SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) AS low_score_orders,
    ROUND(SUM(revenue), 2) AS revenue_brl,
    ROUND(SUM(freight), 2) AS freight_brl
FROM order_rows
GROUP BY purchase_month, customer_state, customer_region, bucket_order, handoff_status
ORDER BY purchase_month, customer_state, bucket_order, handoff_status;
