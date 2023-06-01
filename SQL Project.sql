-- SQL Projuct: Customers and Product Analysis
--
-- In this project, we will explore (and clean if necessarily) a scaled model car database, 
-- with the hope to answer some business intelligence questions such as:
--
-- Q1. Which products should we order more of or less of?
-- Q2. How should we tailor marketing and communication strategies to customer behaviors?
-- Q3. How much can we spend on acquiring new customers?
--
-- The database contains 8 different tables. Below is a brief description of each one:
--
-- customers: contains information on each customer (name, contact, address etc.)
-- employees: contains details on each employee (name, work location, reporting hierarchy etc.)
-- offices: contains details of each office of the company
-- orderdetails: contains details of what was on the order (product code, quantity)
-- orders: contains details about the order made (dates, status etc.)
-- payments: contains details on payment for each customer
-- productlines: contains text and html descriptions of each product line
-- products: contains details about each product 
-- The database schema can be found here: https://dq-content.s3.amazonaws.com/600/db.png
--
-- First, we shall look at all the tables:
SELECT 'customers' AS table_name, 13 AS number_of_attributes, count(*) AS ROWS
  FROM customers

 UNION ALL

SELECT 'employees' AS table_name, 8 AS number_of_attributes, count(*) AS ROWS
  FROM employees

 UNION ALL

SELECT 'offices' AS table_name, 9 AS number_of_attributes, count(*) AS ROWS
  FROM offices

 UNION ALL

SELECT 'orderdetails' AS table_name, 5 AS number_of_attributes, count(*) AS ROWS
  FROM orderdetails

 UNION ALL

SELECT 'orders' AS table_name, 7 AS number_of_attributes, count(*) AS ROWS
  FROM orders

 UNION ALL

SELECT 'payments' AS table_name, 4 AS number_of_attributes, count(*) AS ROWS
  FROM payments

 UNION ALL

SELECT 'productlines' AS table_name, 4 AS number_of_attributes, count(*) AS ROWS
  FROM productlines;

-- Next, we shall determine the answer for the first question:  Which products should we order more of or less of?
-- by identifying stock levels and performance of products. This would optimise the supply and user experience
-- by preventing the best-selling products from running out-of-stock.
--
-- First, let's look at which are the products based on the percentage of stock that has been ordered
--, and check if the amount ordered can be fufilled based on current stock levels

SELECT od.productcode,
		SUM(od.quantityordered) AS quantity_ordered, 
		p.quantityInStock,
		CASE WHEN quantityInStock < SUM(od.quantityordered) THEN "Insufficient Stock" ELSE "OK" END AS stock_status
  FROM orderdetails od
  JOIN products p
    ON od.productcode = p.productcode
 GROUP BY 1;

-- From the above, we can see some products were ordered more than what the stock has to offer. Specifically, the following:

SELECT od.productcode,
	   SUM(od.quantityordered) AS quantity_ordered, 
	   p.quantityInStock,
	   CASE 
			WHEN quantityInStock < SUM(od.quantityordered) 
			THEN "Insufficient Stock" 
			ELSE "OK" 
		END 
			AS stock_status
  FROM orderdetails od
  JOIN products p
    ON od.productcode = p.productcode
 GROUP BY 1
HAVING stock_status <> 'OK';

-- However, to dive in further, we need to see how many orders acutally needs fufilling 
-- as the database contains orders of different statuses. We can identify that by joining the orders table.

SELECT od.orderNumber, o.status, o.comments
  FROM orderdetails od
  JOIN orders o
    ON od.orderNumber = o.orderNumber
 WHERE o.status <> "Shipped"
 GROUP BY 1;

-- From the above, we can see there are some orders yet to be fufilled, 
-- namely thoses with a status of "On Hold" and "In Process"
-- Let's check if the current stock levels are sufficient to fulfill these orders should their status change

SELECT od.productCode, SUM(od.quantityOrdered) AS total_ordered, p.quantityInStock
  FROM orderdetails od
    JOIN products p
	  ON od.productCode = p.productCode
 WHERE od.orderNumber IN (
		SELECT o.orderNumber
		FROM orders o
		WHERE o.status IN ('On Hold' ,'In Process')
		)
 GROUP BY od.productCode;
 
 -- It would appear there are enough stokc to fulfill the pending orders, so we are all good.
 -- Next, let's take a look at how each product performs based on how much it has been ordered and its price. 
 -- We'll see which are the top 10 products.
 
  WITH product_prfrm AS (
SELECT productCode, SUM(quantityOrdered * priceEach) as total_price
  FROM orderdetails
 GROUP BY productcode
)
SELECT p.productName, p.productLine, pp.total_price
  FROM product_prfrm pp
  JOIN products p
    ON pp.productcode = p.productCode
 GROUP BY pp.productCode
 ORDER BY 3 DESC
 LIMIT 10;
 
 -- Given the above, we can now prioritise re-stocking these should it become low.
 
 
 -- Next, let's try and answer Q2: How should we tailor marketing and communication strategies to customer behaviors?
 -- Let's move on from looking at products to cusotmer information to help answer this question.
 -- We shall categorise each customer based on the amount they have spent with the company.
 
 SELECT o.customerNumber, SUM(od.quantityOrdered * (od.priceEach-p.buyPrice)) AS profit_generated
   FROM orders o
   JOIN orderdetails od
     ON o.orderNumber = od.orderNumber
   JOIN products p
     ON od.productcode = p.productCode
  GROUP BY 1;
  
 -- Now that we have the information on how much each customer protis the company,
 -- let's find out the Top 5 VIP level customer.
 
   WITH customer_profit AS (
		  SELECT o.customerNumber, SUM(od.quantityOrdered * (od.priceEach-p.buyPrice)) AS profit_generated
			FROM orders o
			JOIN orderdetails od
			  ON o.orderNumber = od.orderNumber
			JOIN products p
			  ON od.productcode = p.productCode
		   GROUP BY 1
  )

SELECT c.contactFirstName || ' ' || c.contactLastName AS customer_name, c.city || ', '|| c.country AS location, cp.profit_generated
  FROM customer_profit cp
  JOIN customers c
    ON cp.customerNumber = c.customerNumber
 ORDER BY cp.profit_generated DESC
 LIMIT 5;
 
 -- Now that we have the top spenders with the company, should we ever need to organise events to drive loyalty
 -- , we have the contacts at the ready.
 -- NB: On joining the customer's first and last names together, I noticed extra space (' ') is found in some names, 
 -- so some data cleaning is needed.
 
 -- Next, let's bring out attention of the 3rd question: How much can we spend on acquiring new customers?
 -- First, let's take a look at historical customer numbers:
 
  WITH 
-- We first convert the date into a substring of yyyymm format as an additional column
payment_by_year_month_table AS (
SELECT *, 
       CAST(SUBSTR(paymentDate, 1,4) AS INTEGER)*100 + CAST(SUBSTR(paymentDate, 6,7) AS INTEGER) AS year_month
  FROM payments p
),
-- We then use this new column to count how many customers and amount paid per month
customers_by_month_table AS (
SELECT p1.year_month, COUNT(*) AS number_of_customers, SUM(p1.amount) AS total_spend
  FROM payment_by_year_month_table p1
 GROUP BY p1.year_month
),
-- Next, we determine how many of these customers per month are new to the company 
-- (i.e. did not appear in the previous month's payment)
new_customers_by_month_table AS (
SELECT p1.year_month, 
       COUNT(*) AS number_of_new_customers,
       SUM(p1.amount) AS new_customer_total,
        (SELECT number_of_customers
           FROM customers_by_month_table c
          WHERE c.year_month = p1.year_month) AS number_of_customers,
        (SELECT total_spend
           FROM customers_by_month_table c
          WHERE c.year_month = p1.year_month) AS total
  FROM payment_by_year_month_table p1
 WHERE p1.customerNumber NOT IN (SELECT customerNumber
                                   FROM payment_by_year_month_table p2
                                  WHERE p2.year_month < p1.year_month)
 GROUP BY p1.year_month
)

--Lastly, we express the findings as percentages of customer that are new, 
-- and the percentage of that month's payment is made by the new customers
SELECT year_month, 
       ROUND(number_of_new_customers*100/number_of_customers,1) AS pct_of_new_customers,
       ROUND(new_customer_total*100/total,1) AS pct_new_customer_spending
  FROM new_customers_by_month_table;
  
 -- As an example, we can wee in July, 2003 75% of the paying customers are new, making up for 68.3% of that months billing.
 -- This declined steadily to 10% and 6.5% respectively in July, 2004. 
 -- Furthermore, the fact that there are 2005 data in the table but it is not showing in the table above 
 -- indicates the company have not had new customers since September 2004! 
 -- This calls for a plan to acquire new customers for the growth of the company.
 
 -- To determine how to the company can spend to acquire new customers, we need to find out what's the Customer Lifetime Value (LTV)
 -- We can reuse a query from early on:
 
    WITH customer_profit AS (
		  SELECT o.customerNumber, SUM(od.quantityOrdered * (od.priceEach-p.buyPrice)) AS profit_generated
			FROM orders o
			JOIN orderdetails od
			  ON o.orderNumber = od.orderNumber
			JOIN products p
			  ON od.productcode = p.productCode
		   GROUP BY 1
		   )
SELECT avg(profit_generated) AS average_profit
FROM customer_profit

-- We can see that the average customer would generate 39,000 during their lifetime with the company


-- In summary, this project that aims to analyze a scaled model car database and answer several business intelligence questions. 
-- First, we looked at the overview of the tables in the database, including the number of attributes and rows in each table. This helps in understanding the data structure.
-- Next, we have identified products where the stock is insufficient to fulfill the orders. Additionally, we analysed the performance of each product based on the total amount ordered and identified the top 10 products.
-- Then, we categorised customers based on the amount they have spent with the company and identifies the top 5 VIP-level customers.
-- Finally, we looked at the historical data of customer numbers and calculated the percentage of new customers and their monthly spending, providing insights into the growth of new customers and their contribution to the company's revenue.
-- 

