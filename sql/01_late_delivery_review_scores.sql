-- How much do late deliveries hurt review scores? I group delivered orders by how many
-- days late they arrived and look at the average review in each group.

WITH delivered AS (
    SELECT
        order_id,
        -- I compare dates only. The estimated date has no time of day, so arriving on that day counts as on time.
        CAST(julianday(date(order_delivered_customer_date))
             - julianday(date(order_estimated_delivery_date)) AS INTEGER) AS days_vs_estimate
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
),
latest_review AS (
    -- 547 orders have more than one review, so I keep the most recent one for each order.
    SELECT order_id, review_score
    FROM (
        SELECT order_id, review_score,
               ROW_NUMBER() OVER (PARTITION BY order_id
                                  ORDER BY review_answer_timestamp DESC, review_id) AS rn
        FROM order_reviews
    )
    WHERE rn = 1
),
scored AS (
    SELECT
        d.order_id,
        d.days_vs_estimate,
        CASE WHEN d.days_vs_estimate > 0 THEN 1 ELSE 0 END AS is_late,
        CASE
            WHEN d.days_vs_estimate <= 0 THEN 1
            WHEN d.days_vs_estimate <= 3 THEN 2
            WHEN d.days_vs_estimate <= 7 THEN 3
            WHEN d.days_vs_estimate <= 14 THEN 4
            ELSE 5
        END AS bucket_order,
        r.review_score
    FROM delivered d
    LEFT JOIN latest_review r ON r.order_id = d.order_id
),
labeled AS (
    SELECT *,
        CASE bucket_order
            WHEN 1 THEN 'On time or early'
            WHEN 2 THEN '1-3 days late'
            WHEN 3 THEN '4-7 days late'
            WHEN 4 THEN '8-14 days late'
            ELSE '15+ days late'
        END AS delay_bucket
    FROM scored
)
SELECT
    bucket_order,
    delay_bucket,
    COUNT(*) AS orders,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM labeled), 1) AS share_of_orders_pct,
    COUNT(review_score) AS reviewed_orders,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(100.0 * SUM(review_score <= 2) / COUNT(review_score), 1) AS low_score_pct,  -- 1 or 2 stars
    ROUND(100.0 * SUM(review_score = 5) / COUNT(review_score), 1) AS five_star_pct
FROM labeled
GROUP BY bucket_order, delay_bucket

UNION ALL

-- Two extra rows with the totals for all on-time orders and all late orders.
SELECT
    6 + is_late,
    CASE WHEN is_late = 1 THEN 'All late orders' ELSE 'All on-time orders' END,
    COUNT(*),
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM labeled), 1),
    COUNT(review_score),
    ROUND(AVG(review_score), 2),
    ROUND(100.0 * SUM(review_score <= 2) / COUNT(review_score), 1),
    ROUND(100.0 * SUM(review_score = 5) / COUNT(review_score), 1)
FROM labeled
GROUP BY is_late

ORDER BY bucket_order;
