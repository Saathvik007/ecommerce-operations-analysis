-- Which product categories bring in the most revenue, and how are their reviews?
-- Revenue = item prices in BRL, without freight. It's the value of the products sold, which
-- is different from what Olist earns in commission. Items are rolled up to one row per order
-- and category before joining reviews, so an order with three items in one category only
-- counts once. 780 orders have items in two or more categories, and their review counts for
-- each one. Revenue still adds up to the item total (checked in 00_grain_checks.sql).

WITH delivered AS (
    SELECT
        order_id,
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
),
order_categories AS (
    SELECT
        i.order_id,
        -- Items with no product category show up as 'unknown'. That's 1,603 items across all
        -- orders (00_data_profile.csv) and 1,537 in delivered orders (this query's output).
        COALESCE(t.product_category_name_english, 'unknown') AS category,
        COUNT(*) AS items,
        SUM(i.price) AS revenue
    FROM order_items i
    JOIN delivered d ON d.order_id = i.order_id
    LEFT JOIN products p ON p.product_id = i.product_id
    LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
    GROUP BY i.order_id, category
)
SELECT
    oc.category,
    COUNT(*) AS orders,
    SUM(oc.items) AS items,
    ROUND(SUM(oc.revenue), 2) AS revenue_brl,
    ROUND(100.0 * SUM(oc.revenue) / SUM(SUM(oc.revenue)) OVER (), 1) AS share_of_revenue_pct,
    ROUND(SUM(oc.revenue) / SUM(oc.items), 2) AS avg_item_price_brl,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(100.0 * SUM(r.review_score <= 2) / COUNT(r.review_score), 1) AS low_score_pct,
    ROUND(100.0 * AVG(d.is_late), 1) AS late_rate_pct
FROM order_categories oc
JOIN delivered d ON d.order_id = oc.order_id
LEFT JOIN latest_review r ON r.order_id = oc.order_id
GROUP BY oc.category
ORDER BY revenue_brl DESC;
