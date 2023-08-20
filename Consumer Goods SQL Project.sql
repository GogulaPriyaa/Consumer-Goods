#1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.
SELECT DISTINCT(market) 
FROM dim_customer
WHERE customer = "Atliq Exclusive" AND region = "APAC";

#2. What is the percentage of unique product increase in 2021 vs. 2020? 
#The final output contains these fields, unique_products_2020 unique_products_2021 percentage_chg

WITH unique_products_2020 AS
 (
SELECT fiscal_year,count(product) unique_products_2020 
FROM dim_product
JOIN fact_gross_price
USING (product_code)
WHERE fiscal_year = 2020
),
unique_products_2021 AS (
SELECT fiscal_year,count(product) AS unique_products_2021 
FROM dim_product
JOIN fact_gross_price
USING (product_code)
WHERE fiscal_year = 2021
)
SELECT unique_products_2020,unique_products_2021, 
ROUND((unique_products_2021-unique_products_2020)*100/unique_products_2020,2)
AS Percentage_Change FROM unique_products_2020,unique_products_2021;

#3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts.
#The final output contains 2 fields, segment, product_count
SELECT segment, COUNT(product) AS product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;

#4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? 
#The final output contains these fields, segment, product_count_2020,product_count_2021, difference


WITH product_count_2020 AS
 (
SELECT segment,count(product) product_count_2020 
FROM dim_product
JOIN fact_gross_price
USING (product_code)
WHERE fiscal_year = 2020
GROUP BY segment
),
product_count_2021 AS (
SELECT segment,count(product) AS product_count_2021 
FROM dim_product
JOIN fact_gross_price
USING (product_code)
WHERE fiscal_year = 2021
GROUP BY segment
)

SELECT p1.segment,
p1.product_count_2020,
p2.product_count_2021,
p2.product_count_2021-p1.product_count_2020
AS difference FROM product_count_2020 p1
JOIN product_count_2021 p2
USING (segment)
ORDER BY difference DESC;

#5. Get the products that have the highest and lowest manufacturing costs.
# The final output should contain these fields, product_code, product,manufacturing_cost

SELECT p.product_code,p.product,m.manufacturing_cost
FROM dim_product p
JOIN fact_manufacturing_cost m
USING (product_code)
WHERE m.manufacturing_cost 
IN	(
	SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost
    UNION
    SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost
    )
ORDER BY manufacturing_cost DESC;



/*6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for 
the fiscal year 2021 and in the Indian market. 
The final output contains these fields, 
customer_code 
customer
average_discount_percentage*/

WITH CTE1 AS (
	SELECT customer_code,AVG(pre_invoice_discount_pct) AS pct
    FROM fact_pre_invoice_deductions
    WHERE fiscal_year = 2021
    GROUP BY customer_code),
    
    CTE2 AS (
    SELECT customer_code,customer FROM dim_customer
    WHERE market = "India")
    
SELECT CTE2.customer_code,CTE2.customer, 
ROUND(CTE1.pct*100,3) AS average_discount_pct
FROM CTE1
JOIN CTE2
USING(customer_code)
ORDER BY average_discount_pct DESC
LIMIT 5;

/*7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month . 
This analysis helps to get an idea of low and high-performing months and take strategic decisions. 
The final report contains these columns: 
Month
Year 
Gross sales Amount*/
SELECT get_fiscal_month(s.date) AS fiscal_month,
s.fiscal_year,ROUND(SUM(s.sold_quantity*g.gross_price),2)
AS gross_sales_amount
FROM fact_sales_monthly s
JOIN fact_gross_price g
USING (product_code)
JOIN dim_customer c
USING (customer_code)
WHERE c.customer = "Atliq Exclusive"
GROUP BY fiscal_month,s.fiscal_year
ORDER BY s.fiscal_year;

#or
select concat(monthname(s.date), " ", year(s.date)) as month,
s.fiscal_year,round(sum(s.sold_quantity*g.gross_price),2)
as gross_sales_amount
from fact_sales_monthly s
join fact_gross_price g
using (product_code)
join dim_customer c
using (customer_code)
where c.customer = "Atliq Exclusive"
group by month,s.fiscal_year
order by s.fiscal_year;

/*8. In which quarter of 2020, got the maximum total_sold_quantity? 
The final output contains these fields sorted by the total_sold_quantity 
Quarter 
total_sold_quantity*/
SELECT
get_fiscal_quarter(date) AS quarter,
sum(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = 2020
GROUP BY quarter;

#or

   
SELECT 
CASE
    WHEN date BETWEEN '2019-09-01' AND '2019-11-01' then CONCAT('[',1,'] ',MONTHNAME(date))  
    WHEN date BETWEEN '2019-12-01' AND '2020-02-01' then CONCAT('[',2,'] ',MONTHNAME(date))
    WHEN date BETWEEN '2020-03-01' AND '2020-05-01' then CONCAT('[',3,'] ',MONTHNAME(date))
    WHEN date BETWEEN '2020-06-01' AND '2020-08-01' then CONCAT('[',4,'] ',MONTHNAME(date))
    END AS Quarters,
    SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = 2020
GROUP BY Quarters;

/*9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
The final output contains these fields, 
channel 
gross_sales_mln
 percentage*/

WITH cte AS (
SELECT c.channel,
round(sum(s.sold_quantity*g.gross_price)/1000000,2) AS gross_sales_mln
FROM fact_sales_monthly s
JOIN dim_customer c
USING (customer_code)
JOIN fact_gross_price g
USING (product_code)
WHERE s.fiscal_year =2021
GROUP BY c.channel
),
cte1 AS (
SELECT sum(gross_sales_mln) AS total FROM cte
)
SELECT channel,
gross_sales_mln,ROUND(gross_sales_mln*100/total,2) AS percentage
FROM cte,cte1
ORDER BY percentage DESC;


/*10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
The final output contains these fields, 
division 
product_code
product
total_sold_quantity
rank_order*/
WITH cte AS (
	SELECT p.division,
	s.product_code,
	p.product,p.variant,
	sum(s.sold_quantity) AS total_sold_quantity
	FROM fact_sales_monthly s
	JOIN dim_product p
	USING (product_code)
	WHERE fiscal_year = 2021
	GROUP BY p.division,s.product_code,p.product,p.variant
),
rank_order AS (
	SELECT division,product, variant,product_code,
	RANK() OVER(PARTITION BY division ORDER BY total_sold_quantity DESC) AS rank_order
	FROM cte 
)
SELECT cte.division,cte.product_code,concat(cte.product," - ",cte.variant) AS product,
cte.total_sold_quantity,rank_order.rank_order
FROM cte 
JOIN rank_order USING (product_code)
WHERE rank_order IN(1,2,3)








