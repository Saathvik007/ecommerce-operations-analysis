-- Orders, revenue and late rate for each purchase month from January 2017 to August 2018.
-- I left out 2016 (under 300 delivered orders) and the few orders after August 2018.

WITH delivered AS (
    SELECT
        order_id,
        substr(order_purchase_timestamp, 1, 7) AS purchase_month,
        CASE WHEN date(order_delivered_customer_date) > date(order_estimated_delivery_date)
             THEN 1 ELSE 0 END AS is_late
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_purchase_timestamp >= '2017-01-01'
      AND order_purchase_timestamp < '2018-09-01'
),
order_totals AS (
    SELECT order_id, SUM(price) AS revenue, SUM(freight_value) AS freight
    FROM order_items
    GROUP BY order_id
),
monthly AS (
    SELECT
        d.purchase_month,
        COUNT(*) AS orders,
        SUM(t.revenue) AS revenue,
        SUM(t.freight) AS freight,
        SUM(d.is_late) AS late_orders
    FROM delivered d
    JOIN order_totals t ON t.order_id = d.order_id
    GROUP BY d.purchase_month
)
SELECT
    purchase_month,
    orders,
    ROUND(revenue, 2) AS revenue_brl,
    ROUND(revenue / orders, 2) AS avg_order_revenue_brl,
    ROUND(100.0 * freight / (revenue + freight), 1) AS freight_share_pct,
    ROUND(100.0 * late_orders / orders, 1) AS late_rate_pct,
    LAG(orders, 12) OVER (ORDER BY purchase_month) AS orders_same_month_prior_year,
    ROUND(100.0 * (orders - LAG(orders, 12) OVER (ORDER BY purchase_month))
          / LAG(orders, 12) OVER (ORDER BY purchase_month), 1) AS orders_yoy_change_pct
FROM monthly
ORDER BY purchase_month;
