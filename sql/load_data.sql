-- Loads the Olist CSVs from data/raw/ into SQLite.
-- Run from the project folder:  sqlite3 data/olist.db < sql/load_data.sql
-- The geolocation file is skipped because no query uses it and it is half the raw data.
-- Running it again rebuilds every table from scratch.

.bail on

DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS order_payments;
DROP TABLE IF EXISTS order_reviews;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS sellers;
DROP TABLE IF EXISTS category_translation;

-- Primary keys are only declared where the source has one row per key,
-- so a bad reload fails with an error instead of quietly duplicating rows.
CREATE TABLE customers (
    customer_id TEXT PRIMARY KEY,
    customer_unique_id TEXT NOT NULL,
    customer_zip_code_prefix TEXT,
    customer_city TEXT,
    customer_state TEXT);

CREATE TABLE orders (
    order_id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL,
    order_status TEXT,
    order_purchase_timestamp TEXT,
    order_approved_at TEXT,
    order_delivered_carrier_date TEXT,
    order_delivered_customer_date TEXT,
    order_estimated_delivery_date TEXT);

CREATE TABLE order_items (
    order_id TEXT NOT NULL,
    order_item_id INTEGER NOT NULL,
    product_id TEXT,
    seller_id TEXT,
    shipping_limit_date TEXT,
    price REAL,
    freight_value REAL,
    PRIMARY KEY (order_id, order_item_id));

CREATE TABLE order_payments (
    order_id TEXT NOT NULL,
    payment_sequential INTEGER NOT NULL,
    payment_type TEXT,
    payment_installments INTEGER,
    payment_value REAL,
    PRIMARY KEY (order_id, payment_sequential));

-- review_id is not unique in the source (some reviews cover several orders),
-- so this table has no primary key. The queries keep one review per order.
CREATE TABLE order_reviews (
    review_id TEXT NOT NULL,
    order_id TEXT NOT NULL,
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TEXT,
    review_answer_timestamp TEXT);

-- The source spells two columns "lenght", so I renamed them to "length" here.
CREATE TABLE products (
    product_id TEXT PRIMARY KEY,
    product_category_name TEXT,
    product_name_length INTEGER,
    product_description_length INTEGER,
    product_photos_qty INTEGER,
    product_weight_g REAL,
    product_length_cm REAL,
    product_height_cm REAL,
    product_width_cm REAL);

CREATE TABLE sellers (
    seller_id TEXT PRIMARY KEY,
    seller_zip_code_prefix TEXT,
    seller_city TEXT,
    seller_state TEXT);

CREATE TABLE category_translation (
    product_category_name TEXT PRIMARY KEY,
    product_category_name_english TEXT);

-- .import puts every value in as text and turns empty cells into '' instead of NULL.
-- So each file goes into a plain staging table first, and the INSERT below turns ''
-- into NULL with NULLIF. The column types above then store numbers as numbers.
-- --skip 1 skips the header row.

DROP TABLE IF EXISTS stage;
CREATE TABLE stage (c1, c2, c3, c4, c5);
.import --csv --skip 1 data/raw/olist_customers_dataset.csv stage
INSERT INTO customers SELECT NULLIF(c1,''), NULLIF(c2,''), NULLIF(c3,''), NULLIF(c4,''), NULLIF(c5,'') FROM stage;

DROP TABLE stage;
CREATE TABLE stage (c1, c2, c3, c4, c5, c6, c7, c8);
.import --csv --skip 1 data/raw/olist_orders_dataset.csv stage
INSERT INTO orders SELECT NULLIF(c1,''), NULLIF(c2,''), NULLIF(c3,''), NULLIF(c4,''), NULLIF(c5,''),
                          NULLIF(c6,''), NULLIF(c7,''), NULLIF(c8,'') FROM stage;

DROP TABLE stage;
CREATE TABLE stage (c1, c2, c3, c4, c5, c6, c7);
.import --csv --skip 1 data/raw/olist_order_items_dataset.csv stage
INSERT INTO order_items SELECT NULLIF(c1,''), NULLIF(c2,''), NULLIF(c3,''), NULLIF(c4,''), NULLIF(c5,''),
                               NULLIF(c6,''), NULLIF(c7,'') FROM stage;

DROP TABLE stage;
CREATE TABLE stage (c1, c2, c3, c4, c5);
.import --csv --skip 1 data/raw/olist_order_payments_dataset.csv stage
INSERT INTO order_payments SELECT NULLIF(c1,''), NULLIF(c2,''), NULLIF(c3,''), NULLIF(c4,''), NULLIF(c5,'') FROM stage;

DROP TABLE stage;
CREATE TABLE stage (c1, c2, c3, c4, c5, c6, c7);
.import --csv --skip 1 data/raw/olist_order_reviews_dataset.csv stage
INSERT INTO order_reviews SELECT NULLIF(c1,''), NULLIF(c2,''), NULLIF(c3,''), NULLIF(c4,''), NULLIF(c5,''),
                                 NULLIF(c6,''), NULLIF(c7,'') FROM stage;

DROP TABLE stage;
CREATE TABLE stage (c1, c2, c3, c4, c5, c6, c7, c8, c9);
.import --csv --skip 1 data/raw/olist_products_dataset.csv stage
INSERT INTO products SELECT NULLIF(c1,''), NULLIF(c2,''), NULLIF(c3,''), NULLIF(c4,''), NULLIF(c5,''),
                            NULLIF(c6,''), NULLIF(c7,''), NULLIF(c8,''), NULLIF(c9,'') FROM stage;

DROP TABLE stage;
CREATE TABLE stage (c1, c2, c3, c4);
.import --csv --skip 1 data/raw/olist_sellers_dataset.csv stage
INSERT INTO sellers SELECT NULLIF(c1,''), NULLIF(c2,''), NULLIF(c3,''), NULLIF(c4,'') FROM stage;

DROP TABLE stage;
CREATE TABLE stage (c1, c2);
.import --csv --skip 1 data/raw/product_category_name_translation.csv stage
INSERT INTO category_translation SELECT NULLIF(c1,''), NULLIF(c2,'') FROM stage;
DROP TABLE stage;

-- Two categories in products have no English name in the translation file.
INSERT INTO category_translation VALUES
    ('pc_gamer', 'pc_gamer'),
    ('portateis_cozinha_e_preparadores_de_alimentos', 'portable_kitchen_food_preparers');

CREATE INDEX idx_items_order ON order_items(order_id);
CREATE INDEX idx_reviews_order ON order_reviews(order_id);
CREATE INDEX idx_payments_order ON order_payments(order_id);
CREATE INDEX idx_orders_customer ON orders(customer_id);

-- Remove the space left by the staging tables.
VACUUM;

-- Row counts, as a quick check that every file loaded.
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'category_translation', COUNT(*) FROM category_translation;
