-- Is the delay mostly sellers shipping late, or time in transit? I call an order "handed over
-- late" when the carrier picked it up after the seller's shipping deadline.

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
    -- If an order has several items or sellers, I use the latest shipping_limit_date in it.
    -- That gives sellers the benefit of the doubt.
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
