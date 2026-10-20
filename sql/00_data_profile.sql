-- Table sizes, plus counts of the things that make the joins tricky, like orders with more
-- than one review or seller. The counts I quote in the comments, the README and
-- data/README.md come from this output.

WITH delivered AS (
    SELECT order_id
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
)
SELECT 'rows: orders' AS metric, COUNT(*) AS value FROM orders
UNION ALL SELECT 'rows: order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'rows: order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'rows: order_reviews', COUNT(*) FROM order_reviews
UNION ALL SELECT 'rows: customers', COUNT(*) FROM customers
UNION ALL SELECT 'rows: products', COUNT(*) FROM products
UNION ALL SELECT 'rows: sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'rows: category_translation', COUNT(*) FROM category_translation
UNION ALL SELECT 'delivered orders with a delivery date', COUNT(*) FROM delivered
UNION ALL SELECT 'unique customers (customer_unique_id)', COUNT(DISTINCT customer_unique_id) FROM customers
UNION ALL SELECT 'orders with more than one review',
    (SELECT COUNT(*) FROM (SELECT order_id FROM order_reviews GROUP BY order_id HAVING COUNT(*) > 1))
UNION ALL SELECT 'delivered orders with more than one seller',
    (SELECT COUNT(*) FROM (
        SELECT i.order_id FROM order_items i JOIN delivered d ON d.order_id = i.order_id
        GROUP BY i.order_id HAVING COUNT(DISTINCT i.seller_id) > 1))
UNION ALL SELECT 'delivered orders spanning more than one category',
    (SELECT COUNT(*) FROM (
        SELECT i.order_id FROM order_items i
        JOIN delivered d ON d.order_id = i.order_id
        LEFT JOIN products p ON p.product_id = i.product_id
        GROUP BY i.order_id HAVING COUNT(DISTINCT COALESCE(p.product_category_name, 'unknown')) > 1))
UNION ALL SELECT 'items with no product category',
    (SELECT COUNT(*) FROM order_items i LEFT JOIN products p ON p.product_id = i.product_id
      WHERE p.product_category_name IS NULL)
UNION ALL SELECT 'delivered orders reaching the customer before the carrier pickup date',
    (SELECT COUNT(*) FROM orders o JOIN delivered d ON d.order_id = o.order_id
      WHERE o.order_delivered_customer_date < o.order_delivered_carrier_date)
UNION ALL SELECT 'delivered orders with a carrier pickup date before the purchase time',
    (SELECT COUNT(*) FROM orders o JOIN delivered d ON d.order_id = o.order_id
      WHERE o.order_delivered_carrier_date < o.order_purchase_timestamp)
UNION ALL SELECT 'orders with no items',
    (SELECT COUNT(*) FROM orders o WHERE NOT EXISTS (SELECT 1 FROM order_items i WHERE i.order_id = o.order_id));
