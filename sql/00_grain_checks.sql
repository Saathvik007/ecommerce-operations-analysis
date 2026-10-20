-- Checks for the joins in queries 01-08. Each row compares a row count (or a total) before
-- and after a join or roll-up, and passed = 1 means nothing was dropped or counted twice.
-- If a check fails, run_all.sql stops before it writes any other output.

WITH delivered AS (
    SELECT order_id, customer_id, order_purchase_timestamp
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
order_sellers AS (
    SELECT order_id, seller_id FROM order_items GROUP BY order_id, seller_id
),
order_categories AS (
    SELECT i.order_id, COALESCE(t.product_category_name_english, 'unknown') AS category,
           SUM(i.price) AS revenue
    FROM order_items i
    JOIN delivered d ON d.order_id = i.order_id
    LEFT JOIN products p ON p.product_id = i.product_id
    LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
    GROUP BY i.order_id, category
),
order_totals AS (
    SELECT order_id, SUM(price) AS revenue FROM order_items GROUP BY order_id
),
customer_orders AS (
    SELECT c.customer_unique_id, COUNT(*) AS orders
    FROM delivered d JOIN customers c ON c.customer_id = d.customer_id
    GROUP BY c.customer_unique_id
),
checks AS (
    SELECT 'orders: one row per order_id' AS check_name, 'all' AS used_in,
           (SELECT COUNT(DISTINCT order_id) FROM orders) AS expected,
           (SELECT COUNT(*) FROM orders) AS actual
    UNION ALL
    SELECT 'customers: one row per customer_id', '02, 05',
           (SELECT COUNT(DISTINCT customer_id) FROM customers),
           (SELECT COUNT(*) FROM customers)
    UNION ALL
    SELECT 'latest_review: one row per reviewed order', '01, 02, 04',
           (SELECT COUNT(DISTINCT order_id) FROM order_reviews),
           (SELECT COUNT(*) FROM latest_review)
    UNION ALL
    SELECT 'delivered LEFT JOIN latest_review keeps row count', '01, 02',
           (SELECT COUNT(*) FROM delivered),
           (SELECT COUNT(*) FROM delivered d LEFT JOIN latest_review r ON r.order_id = d.order_id)
    UNION ALL
    SELECT 'delivered JOIN customers keeps row count', '02, 05',
           (SELECT COUNT(*) FROM delivered),
           (SELECT COUNT(*) FROM delivered d JOIN customers c ON c.customer_id = d.customer_id)
    UNION ALL
    SELECT 'order_sellers: one row per order-seller pair', '03',
           (SELECT COUNT(*) FROM (SELECT DISTINCT order_id, seller_id FROM order_items)),
           (SELECT COUNT(*) FROM order_sellers)
    UNION ALL
    SELECT 'order_sellers covers every delivered order', '03',
           (SELECT COUNT(*) FROM delivered),
           (SELECT COUNT(DISTINCT os.order_id) FROM order_sellers os JOIN delivered d ON d.order_id = os.order_id)
    UNION ALL
    SELECT 'order_categories LEFT JOIN latest_review keeps row count', '04',
           (SELECT COUNT(*) FROM order_categories),
           (SELECT COUNT(*) FROM order_categories oc LEFT JOIN latest_review r ON r.order_id = oc.order_id)
    UNION ALL
    SELECT 'order_categories revenue equals item-level revenue (BRL)', '04',
           (SELECT ROUND(SUM(i.price), 2) FROM order_items i JOIN delivered d ON d.order_id = i.order_id),
           (SELECT ROUND(SUM(revenue), 2) FROM order_categories)
    UNION ALL
    SELECT 'customer order counts sum to delivered orders', '05',
           (SELECT COUNT(*) FROM delivered),
           (SELECT SUM(orders) FROM customer_orders)
    UNION ALL
    SELECT 'order_totals: one row per order', '06, 07, 08',
           (SELECT COUNT(DISTINCT order_id) FROM order_items),
           (SELECT COUNT(*) FROM order_totals)
    UNION ALL
    SELECT 'delivered JOIN order_totals keeps row count', '06, 07, 08',
           (SELECT COUNT(*) FROM delivered),
           (SELECT COUNT(*) FROM delivered d JOIN order_totals t ON t.order_id = d.order_id)
    UNION ALL
    -- Query 07 filters on purchase date, so an order with a missing timestamp would quietly drop out.
    SELECT 'every delivered order has a valid purchase timestamp', '07',
           (SELECT COUNT(*) FROM delivered),
           (SELECT COUNT(*) FROM delivered WHERE datetime(order_purchase_timestamp) IS NOT NULL)
)
SELECT check_name, used_in, expected, actual,
       CASE WHEN expected = actual THEN 1 ELSE 0 END AS passed
FROM checks;
