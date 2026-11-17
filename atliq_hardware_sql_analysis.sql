USE gdb023;

-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its
-- business in the APAC region.

SELECT DISTINCT 
    market
FROM dim_customer
WHERE customer = 'Atliq Exclusive' 
  AND region = 'APAC';


-- 2. What is the percentage of unique product increase in 2021 vs. 2020? The
-- final output contains these fields:
-- unique_products_2020
-- unique_products_2021
-- percentage_chg

WITH percentage_unique_product AS (
    SELECT 
        COUNT(DISTINCT CASE WHEN fiscal_year = 2020 THEN product_code END) AS unique_products_2020,
        COUNT(DISTINCT CASE WHEN fiscal_year = 2021 THEN product_code END) AS unique_products_2021
    FROM fact_sales_monthly
)
SELECT 
    unique_products_2020,
    unique_products_2021, 
    ROUND((unique_products_2021 - unique_products_2020) / unique_products_2020 * 100, 2) AS percentage_chg
FROM percentage_unique_product;


-- 3. Provide a report with all the unique product counts for each segment and
-- sort them in descending order of product counts. The final output contains
-- 2 fields:
-- segment
-- product_count

SELECT 
    segment,
    COUNT(DISTINCT product_code) AS product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;


-- 4. Follow-up: Which segment had the most increase in unique products in
-- 2021 vs 2020? The final output contains these fields:
-- segment
-- product_count_2020
-- product_count_2021
-- difference

WITH increase_unique_product AS (
    SELECT
        p.segment,
        COUNT(DISTINCT CASE WHEN sm.fiscal_year = 2020 THEN p.product_code END) AS product_count_2020,
        COUNT(DISTINCT CASE WHEN sm.fiscal_year = 2021 THEN p.product_code END) AS product_count_2021
    FROM dim_product p
    JOIN fact_sales_monthly sm
        ON p.product_code = sm.product_code
    GROUP BY p.segment
)
SELECT 
    segment,
    product_count_2020, 
    product_count_2021,
    (product_count_2021 - product_count_2020) AS difference 
FROM increase_unique_product
ORDER BY difference DESC;


-- 5. Get the products that have the highest and lowest manufacturing costs.
-- The final output should contain these fields:
-- product_code
-- product
-- manufacturing_cost

-- Approach 1: Using UNION with ORDER BY and LIMIT
(
    SELECT 
        mc.product_code,
        p.product,
        mc.manufacturing_cost
    FROM fact_manufacturing_cost mc
    JOIN dim_product p
        ON mc.product_code = p.product_code
    ORDER BY mc.manufacturing_cost DESC
    LIMIT 1
)
UNION
(
    SELECT 
        mc.product_code,
        p.product,
        mc.manufacturing_cost
    FROM fact_manufacturing_cost mc
    JOIN dim_product p
        ON mc.product_code = p.product_code
    ORDER BY mc.manufacturing_cost ASC
    LIMIT 1
);

-- Approach 2: Using Subqueries with MIN() and MAX()
SELECT 
    mc.product_code,
    p.product,
    mc.manufacturing_cost 
FROM fact_manufacturing_cost mc
JOIN dim_product p
    ON mc.product_code = p.product_code
WHERE mc.manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost)
   OR mc.manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost);


-- 6. Generate a report which contains the top 5 customers who received an
-- average high pre_invoice_discount_pct for the fiscal year 2021 and in the
-- Indian market. The final output contains these fields:
-- customer_code
-- customer
-- average_discount_percentage

SELECT 
    c.customer_code,
    c.customer,
    ROUND(AVG(pd.pre_invoice_discount_pct), 4) AS average_discount_percentage
FROM fact_pre_invoice_deductions pd
JOIN dim_customer c
    ON pd.customer_code = c.customer_code
WHERE pd.fiscal_year = 2021 
  AND c.market = 'India'
GROUP BY c.customer_code, c.customer
ORDER BY average_discount_percentage DESC
LIMIT 5;


-- 7. Get the complete report of the Gross sales amount for the customer “Atliq
-- Exclusive” for each month. This analysis helps to get an idea of low and
-- high-performing months and take strategic decisions.
-- The final report contains these columns:
-- Month
-- Year
-- Gross sales Amount

SELECT 
    MONTHNAME(s.date) AS Month,
    s.fiscal_year AS Year,
    ROUND(SUM(gp.gross_price * s.sold_quantity), 2) AS Gross_Sales_Amount
FROM fact_sales_monthly s
JOIN fact_gross_price gp
    ON s.product_code = gp.product_code 
    AND s.fiscal_year = gp.fiscal_year
JOIN dim_customer c
    ON s.customer_code = c.customer_code
WHERE c.customer = 'Atliq Exclusive'
GROUP BY Month, s.fiscal_year
ORDER BY s.fiscal_year;


-- 8. In which quarter of 2020, got the maximum total_sold_quantity? The final
-- output contains these fields sorted by the total_sold_quantity:
-- Quarter
-- total_sold_quantity

SELECT 
    CASE 
        WHEN MONTH(date) IN (9, 10, 11) THEN 1
        WHEN MONTH(date) IN (12, 1, 2) THEN 2
        WHEN MONTH(date) IN (3, 4, 5) THEN 3
        ELSE 4
    END AS Quarter,
    SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = 2020
GROUP BY Quarter
ORDER BY total_sold_quantity DESC;


-- 9. Which channel helped to bring more gross sales in the fiscal year 2021
-- and the percentage of contribution? The final output contains these fields:
-- channel
-- gross_sales_mln
-- percentage

SELECT 
    c.channel,
    ROUND(SUM(gp.gross_price * s.sold_quantity) / 1000000, 2) AS gross_sales_mln,
    ROUND(
        (SUM(gp.gross_price * s.sold_quantity) / (
            SELECT SUM(g.gross_price * sm.sold_quantity)
            FROM fact_gross_price g
            JOIN fact_sales_monthly sm
                ON g.product_code = sm.product_code 
                AND g.fiscal_year = sm.fiscal_year
            WHERE g.fiscal_year = 2021
        )) * 100, 
    2) AS percentage
FROM dim_customer c
JOIN fact_sales_monthly s 
    ON c.customer_code = s.customer_code
JOIN fact_gross_price gp
    ON s.product_code = gp.product_code 
    AND s.fiscal_year = gp.fiscal_year
WHERE s.fiscal_year = 2021
GROUP BY c.channel
ORDER BY gross_sales_mln DESC;


-- 10. Get the Top 3 products in each division that have a high
-- total_sold_quantity in the fiscal_year 2021? The final output contains these fields:
-- division
-- product_code
-- product
-- total_sold_quantity
-- rank_order

WITH Top_products AS (
    SELECT 
        p.division,
        p.product_code,
        p.product,
        SUM(s.sold_quantity) AS total_sold_quantity,
        RANK() OVER (PARTITION BY p.division ORDER BY SUM(s.sold_quantity) DESC) AS rank_order
    FROM dim_product p
    JOIN fact_sales_monthly s
        ON p.product_code = s.product_code
    WHERE s.fiscal_year = 2021
    GROUP BY p.division, p.product_code, p.product
)
SELECT 
    division,
    product_code,
    product,
    total_sold_quantity,
    rank_order
FROM Top_products
WHERE rank_order <= 3;