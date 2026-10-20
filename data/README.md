# Data

The raw data is not in this repo because the unzipped files are 126 MB. To get it:

1. Sign in to Kaggle and open https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
2. Click Download, then "Download dataset as zip" (about 45 MB).
3. Unzip it into `data/raw/` so the CSVs are directly in that folder.
4. From the project folder, run `sqlite3 data/olist.db < sql/load_data.sql` to create `data/olist.db`.

License: CC BY-NC-SA 4.0, published by Olist (the main README explains what that means).

## Tables loaded

| Table | Source file | Rows | One row per |
|---|---|---|---|
| orders | olist_orders_dataset.csv | 99,441 | order |
| order_items | olist_order_items_dataset.csv | 112,650 | item in an order |
| order_payments | olist_order_payments_dataset.csv | 103,886 | payment in an order |
| order_reviews | olist_order_reviews_dataset.csv | 99,224 | review (some orders have more than one) |
| customers | olist_customers_dataset.csv | 99,441 | customer_id (each order gets a new customer_id, and customer_unique_id is the actual person) |
| products | olist_products_dataset.csv | 32,951 | product |
| sellers | olist_sellers_dataset.csv | 3,095 | seller |
| category_translation | product_category_name_translation.csv | 73 (2 added by sql/load_data.sql) | category |

sql/load_data.sql fixes two misspelled column names in the source (`product_name_lenght` and `product_description_lenght` become `..._length`). It also adds English names for two categories that are missing from the translation file. `olist_geolocation_dataset.csv` is not loaded.
