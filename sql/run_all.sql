-- Runs every query and saves each result to outputs/ as a CSV with the same name.
-- Run from the project folder, after load_data.sql:  sqlite3 data/olist.db < sql/run_all.sql
-- The grain checks run first. If any check fails, the run stops before any other
-- output is overwritten.

.bail on
.headers on
.mode csv

-- 1. Grain checks
.output outputs/00_grain_checks.csv
.read sql/00_grain_checks.sql
.output stdout

-- Read the saved checks back in. The CHECK constraint makes the next INSERT fail
-- (and .bail on stops the run) if any check did not pass.
DROP TABLE IF EXISTS grain_check_results;
DROP TABLE IF EXISTS run_guard;
.import --csv outputs/00_grain_checks.csv grain_check_results
CREATE TABLE run_guard (
    failed_checks INTEGER CONSTRAINT all_grain_checks_must_pass CHECK (failed_checks = 0));
INSERT INTO run_guard SELECT COUNT(*) FROM grain_check_results WHERE passed <> '1';

-- 2. Data profile and the eight business questions
.output outputs/00_data_profile.csv
.read sql/00_data_profile.sql
.output outputs/01_late_delivery_review_scores.csv
.read sql/01_late_delivery_review_scores.sql
.output outputs/02_late_rate_by_state.csv
.read sql/02_late_rate_by_state.sql
.output outputs/03_late_rate_by_seller.csv
.read sql/03_late_rate_by_seller.sql
.output outputs/04_category_revenue_reviews.csv
.read sql/04_category_revenue_reviews.sql
.output outputs/05_repeat_customer_rate.csv
.read sql/05_repeat_customer_rate.sql
.output outputs/06_freight_share_by_order_value.csv
.read sql/06_freight_share_by_order_value.sql
.output outputs/07_monthly_orders_revenue.csv
.read sql/07_monthly_orders_revenue.sql
.output outputs/08_seller_handoff_vs_late.csv
.read sql/08_seller_handoff_vs_late.sql

-- 3. Extract for the Tableau dashboard
.output outputs/tableau_extract.csv
.read sql/tableau_extract.sql
.output stdout

-- The extract has to add back up to the number of delivered orders.
DROP TABLE IF EXISTS extract_check;
DROP TABLE run_guard;
.import --csv outputs/tableau_extract.csv extract_check
CREATE TABLE run_guard (
    difference INTEGER CONSTRAINT extract_must_match_delivered_orders CHECK (difference = 0));
INSERT INTO run_guard
SELECT (SELECT SUM(CAST(orders AS INTEGER)) FROM extract_check)
     - (SELECT COUNT(*) FROM orders
        WHERE order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL);

-- Clean up the helper tables.
DROP TABLE grain_check_results;
DROP TABLE extract_check;
DROP TABLE run_guard;

.headers off
.mode list
SELECT 'All grain checks passed, and the Tableau extract adds up to the delivered orders.';
