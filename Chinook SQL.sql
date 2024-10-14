USE chinook

-- 1.	Does any table have missing values or duplicates? If yes how would you handle it ?

-- NULL Values:

select * from album
where album_id is null
or title is null
or artist_id is null
or release_year is null;

select album_id,coalesce(release_year,0) from album;

select * from customer

SELECT customer_id,
       COALESCE(company, 'N/A') AS company,
       COALESCE(state, 'N/A') AS state,
       COALESCE(fax, 'N/A') AS fax
FROM customer;


select * from employee

select employee_id,coalesce(reports_to,0) from employee;

select * from track

select track_id, coalesce(composer,'N/A') as composer from track;


-- Duplicates:


CREATE TEMPORARY TABLE temp_duplicates AS
SELECT a1.invoice_line_id
FROM invoice_line a1
JOIN invoice_line a2
  ON a1.invoice_id = a2.invoice_id
 AND a1.track_id = a2.track_id
 AND a1.invoice_line_id > a2.invoice_line_id;
 
DELETE FROM invoice_line
WHERE invoice_line_id IN (
    SELECT invoice_line_id
    FROM temp_duplicates);

DROP TEMPORARY TABLE temp_duplicates;


CREATE TEMPORARY TABLE temp_duplicates AS
SELECT a1.playlist_id
FROM playlist a1
JOIN playlist a2
  ON a1.name = a2.name
 AND a1.playlist_id > a2.playlist_id;

DELETE FROM playlist
WHERE playlist_id IN (
    SELECT playlist_id
    FROM temp_duplicates);

DROP TEMPORARY TABLE temp_duplicates;

-- 2.	Find the top-selling tracks and top artist in the USA and identify their most famous genres.


select t.track_id,t.name as track_name,sum(il.quantity) as total_sold,g.name as genre_name,ar.name as artist_name,ar.artist_id
from invoice_line il
join invoice i on il.invoice_id = i.invoice_id
join customer c on i.customer_id = c.customer_id
join track t on il.track_id = t.track_id
join album a on t.album_id = a.album_id
join artist ar on a.artist_id = ar.artist_id 
join genre g on g.genre_id = t.genre_id
where i.billing_country = 'USA'
group by t.track_id,t.name,ar.name,g.name
order by total_sold desc
limit 10;


-- 3.	What is the customer demographic breakdown (age, gender, location) of Chinook's customer base?

select country,count(*) as no_of_customers
from customer
group by country
order by no_of_customers desc;

select coalesce(state,'others') as state,count(*) as no_of_customers
from customer
group by state
order by no_of_customers desc;

select city,count(*) as no_of_customers
from customer
group by city
order by no_of_customers desc;


-- 4. Calculate the total revenue and number of invoices for each country, state, and city.

select c.country,coalesce(c.state,'N.A.') as state,c.city,
sum(i.total) as total_sale,count(i.invoice_id) as invoices_no
from invoice i
join customer c on i.customer_id = c.customer_id
group by c.country,c.state,c.city
order by total_sale desc;


-- 5.	Find the top 5 customers by total revenue in each country

SELECT c.customer_id, CONCAT(c.first_name,' ', c.last_name) as customer_name,
c.country, SUM(i.total) as total_revenue
FROM customer c
INNER JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id, customer_name, c.country
ORDER BY total_revenue DESC
limit 5;


-- 6.	Identify the top-selling track for each customer 


WITH cte1 AS (
SELECT c.customer_id, CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
SUM(il.quantity) AS total_sold
FROM customer c
INNER JOIN invoice i ON c.customer_id = i.customer_id
INNER JOIN invoice_line il ON i.invoice_id = il.invoice_id
INNER JOIN track t ON il.track_id = t.track_id
GROUP BY c.customer_id, customer_name),

cte2 AS (
SELECT cte1.customer_id, cte1.customer_name, cte1.total_sold, t.track_id, t.name,
row_number() OVER (PARTITION BY cte1.customer_id ORDER BY cte1.total_sold DESC) AS track_rank
FROM cte1
INNER JOIN invoice i ON cte1.customer_id = i.customer_id
INNER JOIN invoice_line il ON i.invoice_id = il.invoice_id
INNER JOIN track t ON il.track_id = t.track_id)

SELECT customer_id, customer_name, track_id, name, total_sold, track_rank
FROM cte2
WHERE track_rank = 1
ORDER BY customer_id;



-- 7.	Are there any patterns or trends in customer purchasing behavior 
-- (e.g., frequency of purchases, preferred payment methods, average order value)?


-- Frequency of purchases:

SELECT C.customer_id, CONCAT(c.first_name,' ', c.last_name) as customer_name,
YEAR(i.invoice_date) as year, COUNT(i.invoice_id) as purchase_count
FROM customer c
INNER JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id, customer_name, year
ORDER BY c.customer_id, customer_name, year;


-- Preferred payment mode:

-- Could not find any payment mode related columns in the given database schema.

-- Average order value:

SELECT C.customer_id, CONCAT(c.first_name,' ', c.last_name) as customer_name,
ROUND(AVG(i.total),2) as avg_order_value
FROM customer c
INNER JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id, customer_name
ORDER BY avg_order_value DESC;


-- 8.	What is the customer churn rate?

WITH cte1 as (SELECT MAX(invoice_date) as last_purchase_date FROM invoice),
cte2 as (SELECT DATE_SUB(last_purchase_date,interval 1 year) as last_year_invoice_date from cte1),
cte3 as (SELECT c.customer_id, concat(c.first_name,' ',c.last_name) as customer,
MAX(i.invoice_date) as last_purchase_date
FROM customer c
INNER JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id, customer
HAVING MAX(i.invoice_date) < (SELECT last_year_invoice_date FROM cte2)),
total_customers AS (
SELECT COUNT(*) AS total_count
FROM customer),
churned_customers AS (
SELECT COUNT(*) AS churned_count
FROM cte3)
SELECT(churned_count / total_count) *100 AS churn_rate
FROM churned_customers, total_customers;



-- 9.	Calculate the percentage of total sales contributed by each genre in the USA and identify the best-selling genres and artists.

-- the percentage of total sales contributed by each genre in USA:

WITH genrewise_sales_in_USA as (SELECT g.genre_id, g.name as genre_name,
SUM(il.unit_price*il.quantity) as total_sales
FROM genre g
INNER JOIN track t ON g.genre_id = t.genre_id
INNER JOIN invoice_line il ON t.track_id = il.track_id
INNER JOIN invoice i ON il.invoice_id = i.invoice_id
INNER JOIN customer c ON i.customer_id = c.customer_id
WHERE c.country = 'USA'
GROUP BY g.genre_id, g.name),
Total_genre_sales as (SELECT SUM(total_sales) as overall_genre_sales FROM genrewise_sales_in_USA),
genre_percentage as (SELECT gs.genre_id, gs.genre_name, gs.total_sales,
ROUND((gs.total_sales/tg.overall_genre_sales)*100,2) as sales_percentage
FROM genrewise_sales_in_USA gs
CROSS JOIN Total_genre_sales tg)
SELECT * FROM genre_percentage
ORDER BY sales_percentage DESC;


-- Best-selling genres:

WITH genre_sales AS (
SELECT g.genre_id, g.name AS genre_name,
SUM(il.unit_price * il.quantity) AS total_sales
FROM genre g
INNER JOIN track t ON g.genre_id = t.genre_id
INNER JOIN invoice_line il ON il.track_id = t.track_id
INNER JOIN invoice i ON il.invoice_id = i.invoice_id
INNER JOIN customer c ON i.customer_id = c.customer_id
WHERE c.country = 'USA'
GROUP BY g.genre_id, g.name)

SELECT genre_id, genre_name, total_sales,
DENSE_RANK() OVER (ORDER BY total_sales DESC) AS genre_rank
FROM genre_sales;


-- Best-selling artist:


WITH artist_sales AS (
SELECT a.artist_id, a.name AS artist_name,
SUM(il.unit_price * il.quantity) AS total_sales
FROM artist a
INNER JOIN album al ON a.artist_id = al.artist_id
INNER JOIN track t ON al.album_id = t.album_id
INNER JOIN invoice_line il ON t.track_id = il.track_id
INNER JOIN invoice i ON il.invoice_id = i.invoice_id
INNER JOIN customer c ON i.customer_id = c.customer_id
WHERE c.country = 'USA'
GROUP BY a.artist_id, a.name)

SELECT artist_id, artist_name, total_sales,
DENSE_RANK() OVER (ORDER BY total_sales DESC) AS artist_rank
FROM artist_sales;


-- 10.	Find customers who have purchased tracks from at least 3 different genres

SELECT c.customer_id, CONCAT(c.first_name,' ', c.last_name) as customer_name,
COUNT(DISTINCT g.genre_id) as genre_count
FROM customer c
INNER JOIN invoice i ON c.customer_id = i.customer_id
INNER JOIN invoice_line il ON i.invoice_id = il.invoice_id
INNER JOIN track t ON il.track_id = t.track_id
INNER JOIN genre g ON t.genre_id = g.genre_id
GROUP BY c.customer_id, customer_name
HAVING COUNT(DISTINCT g.genre_id) >= 3
ORDER BY genre_count DESC;



-- 11.	Rank genres based on their sales performance in the USA

WITH genre_sales_in_USA as
(SELECT g.genre_id, g.name as genre_name,
SUM(il.unit_price*il.quantity) as total_sales
FROM genre g
INNER JOIN track t ON g.genre_id = t.genre_id
INNER JOIN invoice_line il ON t.track_id = il.track_id
INNER JOIN invoice i ON il.invoice_id = i.invoice_id
INNER JOIN customer c ON i.customer_id = c.customer_id
WHERE c.country = 'USA'
GROUP BY g.genre_id, g.name)

SELECT genre_id, genre_name, total_sales,
RANK() OVER (ORDER BY total_sales DESC) as genre_rank
FROM genre_sales_in_USA
ORDER BY genre_rank;


-- 12.	Identify customers who have not made a purchase in the last 3 months

WITH recent_purchase_date as
(SELECT c.customer_id, CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
MAX(DATE(i.invoice_date)) AS last_purchase_date
FROM customer c
LEFT JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id, customer_name),

date_period as (SELECT DATE_SUB(last_purchase_date, INTERVAL 3 MONTH) AS date_3_months_ago from recent_purchase_date)

SELECT r.customer_id, r.customer_name, r.last_purchase_date
FROM recent_purchase_date r
INNER JOIN date_period dp ON r.last_purchase_date < dp.date_3_months_ago
GROUP BY r.customer_id, r.customer_name
ORDER BY r.last_purchase_date;


-- Subjective Questions

-- 1.	Recommend the three albums from the new record label that should be prioritised 
-- for advertising and promotion in the USA based on genre sales analysis.


WITH cte1 as (SELECT g.genre_id, g.name AS genre_name,
al.album_id, al.title, SUM(il.unit_price * il.quantity) AS total_genre_sales
FROM album al
INNER JOIN track t ON al.album_id = t.album_id
INNER JOIN genre g ON t.genre_id = g.genre_id
INNER JOIN invoice_line il ON t.track_id = il.track_id
INNER JOIN invoice i ON il.invoice_id = i.invoice_id
INNER JOIN customer c ON i.customer_id = c.customer_id
WHERE c.country = 'USA'
GROUP BY g.genre_id, g.name, al.album_id, al.title)

SELECT genre_id, genre_name, album_id, title, total_genre_sales,
DENSE_RANK() OVER (ORDER BY total_genre_sales DESC) as genre_rank
FROM cte1;


-- 2.	Determine the top-selling genres in countries other than the USA and identify any commonalities or differences.

SELECT g.genre_id, g.name as genre_name, c.country,
SUM(il.quantity) as quantity_sold
FROM genre g
INNER JOIN track t ON g.genre_id = t.genre_id
INNER JOIN invoice_line il ON t.track_id = il.track_id
INNER JOIN invoice i ON il.invoice_id = i.invoice_id
INNER JOIN customer c ON i.customer_id = c.customer_id
WHERE c.country != 'USA'
GROUP BY g.genre_id, genre_name, c.country
ORDER BY quantity_sold DESC;


-- 3.	Customer Purchasing Behavior Analysis: How do the purchasing habits (frequency, basket size, spending amount)
--  of long-term customers differ from those of new customers? What insights can these patterns
--  provide about customer loyalty and retention strategies?

WITH purchasing_behaviour as (SELECT c.customer_id, COUNT(i.invoice_id) as purchase_frequency,
SUM(il.quantity) as total_items_purchased,
SUM(i.total) as total_spent,
AVG(i.total) as avg_order_value,
DATEDIFF(MAX(i.invoice_date), MIN(i.invoice_date)) as days_between
FROM customer c
INNER JOIN invoice i ON c.customer_id = i.customer_id
INNER JOIN invoice_line il ON i.invoice_id = il.invoice_id
GROUP BY c.customer_id),

customer_segment as (SELECT customer_id, purchase_frequency,
total_items_purchased, total_spent,
avg_order_value, days_between,
CASE WHEN days_between >= 365 then 'Long term'
ELSE 'New'
END as customer_segment
FROM purchasing_behaviour)

SELECT customer_id, customer_segment, ROUND(AVG(purchase_frequency),2) as avg_purchase_frequency,
ROUND(AVG(total_items_purchased),2) as avg_basket_size, ROUND(AVG(total_spent),2) as avg_spending_amount,
ROUND(AVG(avg_order_value),2) AS avg_order_value
FROM customer_segment
GROUP BY customer_id, customer_segment;



-- 4.	Product Affinity Analysis: Which music genres, artists, or albums are frequently purchased together by customers?
--  How can this information guide product recommendations and cross-selling initiatives?

select g.name as genre_name, a.title as album_name,
ar.name as artist_name,count(i.invoice_id) as purchase,
dense_rank() over(order by count(i.invoice_id)desc) as ranking from invoice_line il 
join invoice i on il.invoice_id = i.invoice_id
join customer c on i.customer_id = c.customer_id
join track t on il.track_id = t.track_id
join album a on t.album_id = a.album_id
join artist ar on a.artist_id = ar.artist_id 
join genre g on g.genre_id = t.genre_id 
group by g.name,a.title,t.name,ar.name
order by purchase desc;


-- 5.	Regional Market Analysis: Do customer purchasing behaviours and churn rates vary across different 
-- geographic regions or store locations? How might these correlate with local demographic or economic factors?

-- -- Customer Purchasing Behaviors by Region -- --

WITH purchase_frequency AS (
SELECT
customer_id, COUNT(invoice_id) AS total_purchase_freq,
SUM(total) AS total_spending, AVG(total) AS avg_order_value
FROM invoice
GROUP BY customer_id),

customer_region_summary AS (
SELECT c.customer_id, c.country,COALESCE(c.state, 'N.A') AS state,
c.city, pf.total_purchase_freq,
pf.total_spending, pf.avg_order_value
FROM customer c
JOIN purchase_frequency pf ON c.customer_id = pf.customer_id)

SELECT country, state, city,
COUNT(DISTINCT customer_id) AS total_customers,
ROUND(SUM(total_purchase_freq), 2) AS total_purchases,
ROUND(SUM(total_spending), 2) AS total_spending,
ROUND(AVG(avg_order_value), 2) AS avg_order_value,
ROUND(AVG(total_purchase_freq), 2) AS avg_purchase_frequency
FROM customer_region_summary
GROUP BY country, state, city;


-- -- Churn Rate by Region -- --

WITH last_purchase AS (
SELECT c.customer_id, c.country, COALESCE(c.state,'N.A') as state,
c.city, MAX(i.invoice_date) AS last_purchase_date
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id, c.country, c.state, c.city),
churned_customers AS (
SELECT country, state, city,COUNT(customer_id) AS churned_customers
FROM last_purchase
WHERE last_purchase_date < DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
GROUP BY country, state, city)
SELECT lc.country, lc.state, lc.city, lc.churned_customers,
COUNT(c.customer_id) AS total_customers
FROM churned_customers lc
JOIN customer c ON lc.country = c.country AND lc.state = c.state AND lc.city = c.city
GROUP BY lc.country, lc.state, lc.city;


-- 6.	Customer Risk Profiling: Based on customer profiles (age, gender, location, purchase history), 
-- which customer segments are more likely to churn or pose a higher risk of reduced spending? What factors contribute to this risk?


WITH customer_profile AS (
SELECT c.customer_id, c.country, COALESCE(c.state,'N.A') as state,
c.city, MAX(i.invoice_date) AS last_purchase_date,
SUM(i.total) AS total_spending,
COUNT(i.invoice_id) AS purchase_frequency,
AVG(i.total) AS avg_order_value
FROM customer c
LEFT JOIN
invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id),

churn_risk AS (
SELECT cp.customer_id, cp.country, cp.state,
cp.city, cp.total_spending, cp.purchase_frequency, cp.avg_order_value,
CASE WHEN cp.last_purchase_date < DATE_SUB(CURDATE(), INTERVAL 1 YEAR) THEN 'High Risk'
WHEN cp.total_spending < 100 THEN 'Medium Risk'
ELSE 'Low Risk'
END AS risk_profile
FROM customer_profile cp)

SELECT country, state, city, risk_profile,
COUNT(customer_id) AS no_of_customers,
ROUND(AVG(total_spending),2) AS avg_total_spending,
ROUND(AVG(purchase_frequency),2) AS avg_purchase_frequency,
ROUND(AVG(avg_order_value),2) AS avg_order_value
FROM churn_risk
GROUP BY country, state, city, risk_profile
ORDER BY avg_total_spending DESC;


-- 7.	Customer Lifetime Value Modeling: How can you leverage customer data (tenure, purchase history, engagement) to 
-- predict the lifetime value of different customer segments? This could inform targeted marketing and loyalty program strategies. 
-- Can you observe any common characteristics or purchase patterns among customers who have stopped purchasing?

WITH customer_profile AS (
    SELECT c.customer_id, CONCAT(c.first_name, ' ', c.last_name) AS customers,
    c.country, COALESCE(c.state, 'N.A') AS state, c.city,
    MIN(i.invoice_date) AS first_purchase_date, MAX(i.invoice_date) AS last_purchase_date,
    DATEDIFF(MAX(i.invoice_date), MIN(i.invoice_date)) AS customer_tenure_days,
    COUNT(i.invoice_id) AS purchase_frequency,
    SUM(i.total) AS total_spending,
    AVG(i.total) AS avg_order_value
    FROM customer c
    LEFT JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id
),
customer_lifetime_value AS (
    SELECT cp.customer_id, cp.customers, cp.country, cp.state, cp.city,
    cp.customer_tenure_days, cp.purchase_frequency, cp.total_spending, cp.avg_order_value,
    CASE WHEN cp.customer_tenure_days >= 365 THEN 'Long-Term' ELSE 'Short-Term' END AS customer_segment,
    CASE WHEN cp.last_purchase_date < DATE_SUB(CURDATE(), INTERVAL 1 YEAR) THEN 'Churned' ELSE 'Active' END AS customer_status
    FROM customer_profile cp
)
SELECT * FROM customer_lifetime_value
ORDER BY total_spending DESC;


-- 10.	How can you alter the "Albums" table to add a new column named "ReleaseYear"
--  of type INTEGER to store the release year of each album?

ALTER TABLE Albums
ADD Releaseyear INT;


-- 11.	Chinook is interested in understanding the purchasing behavior of customers based on their geographical location. 
-- They want to know the average total amount spent by customers from each country, along with the
-- number of customers and the average number of tracks purchased per customer. Write an SQL query to provide this information.


WITH tracks_per_customer AS (
    SELECT i.customer_id, SUM(il.quantity) AS total_quantity
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    GROUP BY i.customer_id
),
customer_spending AS (
    SELECT c.country, c.customer_id, SUM(i.total) AS total_spent,
           tpc.total_quantity
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    JOIN tracks_per_customer tpc ON c.customer_id = tpc.customer_id
    GROUP BY c.country, c.customer_id, tpc.total_quantity
)
SELECT 
    cs.country,
    COUNT(DISTINCT cs.customer_id) AS number_of_customers,
    ROUND(AVG(cs.total_spent), 2) AS average_amount_spent_per_customer,
    ROUND(AVG(cs.total_quantity), 2) AS average_tracks_purchased_per_customer
FROM customer_spending cs
GROUP BY cs.country
ORDER BY average_amount_spent_per_customer DESC;
