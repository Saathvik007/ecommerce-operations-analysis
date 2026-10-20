-- How much of what customers pay goes to freight, by order size? Order value here is item
-- prices + freight in BRL, and the freight share is total freight / total order value per band.

WITH delivered AS (
    SELECT order_id
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
),
order_totals AS (
    SELECT
        i.order_id,
        SUM(i.price) AS item_value,
        SUM(i.freight_value) AS freight
    FROM order_items i
    JOIN delivered d ON d.order_id = i.order_id
    GROUP BY i.order_id
),
banded AS (
    SELECT *,
        CASE
            WHEN item_value < 50 THEN 1
            WHEN item_value < 100 THEN 2
            WHEN item_value < 200 THEN 3
            WHEN item_value < 500 THEN 4
            ELSE 5
        END AS band_order
    FROM order_totals
)
SELECT
    band_order,
    CASE band_order
        WHEN 1 THEN 'Under 50'
        WHEN 2 THEN '50-99'
        WHEN 3 THEN '100-199'
        WHEN 4 THEN '200-499'
        ELSE '500+'
    END AS item_value_band_brl,
    COUNT(*) AS orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_of_orders_pct,
    ROUND(AVG(item_value), 2) AS avg_item_value_brl,
    ROUND(AVG(freight), 2) AS avg_freight_brl,
    ROUND(100.0 * SUM(freight) / SUM(item_value + freight), 1) AS freight_share_pct,
    ROUND(100.0 * SUM(freight) / SUM(SUM(freight)) OVER (), 1) AS share_of_all_freight_pct
FROM banded
GROUP BY band_order

UNION ALL

SELECT 6, 'All orders', COUNT(*), 100.0,
       ROUND(AVG(item_value), 2), ROUND(AVG(freight), 2),
       ROUND(100.0 * SUM(freight) / SUM(item_value + freight), 1), 100.0
FROM banded

ORDER BY band_order;
