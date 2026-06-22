create database E_CommerceDB;
use E_CommerceDB;
select * from customer_retention;

desc customer_retention;
select * from rfm_df;
desc rfm_df;
-- Exploration Queries
-- 1. Total transactions
select count(distinct InvoiceNo)  as "Total transactions"
from customer_retention;

-- 2. Total customers
select count(distinct CustomerID)  as "Total Customers"
from customer_retention;

-- 3. Total products
select count(distinct StockCode)  as "Total Product"
from customer_retention;

-- 4. Total revenue
select Round(sum(revenue),2)  as "Total Revenue"
from customer_retention;

-- 5. Average order value
select round(sum(revenue) /count(distinct InvoiceNo),2) as "Average Order Value"
from customer_retention;

-- 6. Revenue by country
select Country,   Round(sum(revenue),2) as "Country Revenue"
from customer_retention
group by Country
order by Round(sum(revenue),2) desc  ;

-- Business Analysis Queries

--  7. Top 10 customers by revenue
select  CustomerID,Round(sum(revenue),2) as "customers Revenue"
From customer_retention
group by CustomerID
order by Round(sum(revenue),2) desc limit 10;

--  8. Top 10 products by revenue
select StockCode,Description ,Round(sum(revenue),2) as "products Revenue"
from customer_retention
group by StockCode,Description
order by Round(sum(revenue),2) desc limit 10;

-- 9. Monthly revenue trend
select Month_number , Month ,Round(sum(revenue),2) as "Revenue"
from customer_retention
group by Month_number , Month
order by Month_number ;

-- 10. Quarterly revenue trend
select Quarter ,Round(sum(revenue),2) as "Revenue"
from customer_retention
group by Quarter
order by Quarter;

-- 11. Average revenue per customer
select round(sum(revenue)/count(distinct customerid),2) as "Avrg Revenue per Customer"
from customer_retention;

-- 12. Revenue contribution by country
select Country ,
         round(sum(revenue) /(select sum(revenue) from customer_retention )*100,2) as revenue_contribution_rate
from customer_retention 
group by Country
order by revenue_contribution_rate desc;

-- 13. Repeat purchase rate
select round(count(*) / (select count(customerid) from rfm_df)*100 ,2) as "purchase rate"
from rfm_df
where order_Count >1;

-- 14. Customer churn rate
select round(avg(churn_flag)*100 , 2) as "customer churn_rate"
 from  rfm_df;
 
 -- Intermediate SQL
-- 15. Rank products by revenue using:
select stockCode,description  , Rank() over(order by total_revenue desc) 
from
     (select stockCode,description , sum(revenue) as "total_revenue" 
     from customer_retention 
     group by stockCode,description) t;
-- 16. Top customer in each country using:
select country ,customerid,revenue, row_number() over(partition by  country  order by revenue desc) 
from
(select country ,customerid,round( sum(revenue),3) as "revenue"
from customer_retention
group by country ,customerid) t ;

-- 17. Running revenue total using:
select revenue,
 sum(revenue) over(
				   order by InvoiceDate 
                   rows between unbounded preceding and current row ) 
                   AS running_total
from customer_retention ;


-- 18. Month-over-month revenue growth using:
select month_number, month,year ,revenue , round(((revenue - pre_month_reve)/ pre_month_reve)*100,2)  AS revenue_growth_pct from (
				select month_number, month,year ,revenue , lag(revenue) over(order by  year, month_number) as pre_month_reve from (
						select month_number ,month,year ,round(sum(revenue),2) as revenue 
						from customer_retention 
						group by month_number, month,year ) t
                        order by year,month_number) t2 ;


 -- 19. Month-over-month customer growth using:
 select * , round(((customer_count - pre_monthcoustomer_count ) /pre_monthcoustomer_count)*100,2) AS customer_growth_pct
 from(
		 select * ,lag(customer_count) over(order by year ,month_number) as pre_monthcoustomer_count
		 from(
				 select month_number ,month ,year ,count(distinct CustomerID) as customer_count
				 from customer_retention
				 group by month_number,month,year)t)t2;
		 
 
 
-- Advanced SQL
-- Pareto Analysis
-- Do 20% of customers generate 80% of revenue?
select round(
			(sum(Monetary)/ (select sum(Monetary) from rfm_df)) *100,2)
            AS revenue_percentage 
            from
			 (select customerid,Monetary , 
             row_number() over(order by Monetary desc) as rn,
             COUNT(*) OVER () AS total_customers
			  from rfm_df) t
              where t.rn <= ceil(0.2 * total_customers );
		

-- 21. Customer Segmentation Analysis
-- Revenue by:
-- Champions
-- Loyal
-- At Risk
-- Lost
select customer_segment,
round(sum(Monetary),2) as segment_revenue 
from rfm_df
group by customer_segment
order by segment_revenue desc ;

-- 22. Churn Analysis by Country
desc rfm_df ;
select Country ,round(avg(churn_flag)*100,2) as churn_percent 
from rfm_df
group by Country
order by churn_percent desc;

-- 23. Cohort Retention Analysis
-- Create:
-- First Purchase Month
-- Calculate:
-- Month 1 Retention
-- Month 2 Retention
-- Month 3 Retention
WITH first_purchase AS (
    SELECT
        CustomerID,
        MIN(DATE_FORMAT(InvoiceDate, '%Y-%m-01')) AS cohort_month
    FROM customer_retention
    GROUP BY CustomerID
),

customer_activity AS (
    SELECT
        fp.CustomerID,
        fp.cohort_month,
        DATE_FORMAT(c.InvoiceDate, '%Y-%m-01') AS activity_month,
        TIMESTAMPDIFF(
            MONTH,
            fp.cohort_month,
            DATE_FORMAT(c.InvoiceDate, '%Y-%m-01')
        ) AS month_number
    FROM customer_retention c
    JOIN first_purchase fp
        ON c.CustomerID = fp.CustomerID
)

SELECT
    cohort_month,
    COUNT(DISTINCT CASE WHEN month_number = 0 THEN CustomerID END) AS Cohort_Size,

    ROUND(
        COUNT(DISTINCT CASE WHEN month_number = 1 THEN CustomerID END)
        /
        COUNT(DISTINCT CASE WHEN month_number = 0 THEN CustomerID END)
        * 100,2
    ) AS Month1_Retention,

    ROUND(
        COUNT(DISTINCT CASE WHEN month_number = 2 THEN CustomerID END)
        /
        COUNT(DISTINCT CASE WHEN month_number = 0 THEN CustomerID END)
        * 100,2
    ) AS Month2_Retention,

    ROUND(
        COUNT(DISTINCT CASE WHEN month_number = 3 THEN CustomerID END)
        /
        COUNT(DISTINCT CASE WHEN month_number = 0 THEN CustomerID END)
        * 100,2
    ) AS Month3_Retention

FROM customer_activity
GROUP BY cohort_month
ORDER BY cohort_month;
-- Q24. Identify customers whose spending decreased month-over-month.
select CustomerID,year,month ,round(((t2.revenue - t2.pre_month_revenue) /t2.revenue)*100 ,2) as decreasing_rate
from(
select CustomerID ,
	year,month_number,month,
    revenue,lag(revenue) over(partition by CustomerID order by year ,month_number) as pre_month_revenue
from(
select CustomerID ,year,month_number,month,sum(revenue) as revenue
		from customer_retention 
		group by  year,month_number,month,CustomerID)t) t2 
        where pre_month_revenue IS NOT NULL AND revenue < pre_month_revenue
        ORDER BY
		CustomerID,
		year,
		month_number;
        
        

-- 25. Create final analytics table for Tableau.

CREATE TABLE tableau_final AS
SELECT
    c.InvoiceNo,
    c.InvoiceDate,
    c.year,
    c.month_number,
    c.month,

    c.CustomerID,
    c.Country,

    c.StockCode,
    c.Description,

    c.Quantity,
    c.UnitPrice,
    c.Revenue,

    r.Recency,
    r.Frequency,
    r.Monetary,

    r.Recency_Score,
    r.Frequency_Score,
    r.Monetary_Score,

    r.Customer_Segment,
    r.Churn_Flag

FROM customer_retention c
LEFT JOIN rfm_df r
ON c.CustomerID = r.CustomerID;

select * from tableau_final;
 SELECT CustomerID, COUNT(*)
FROM rfm_df
GROUP BY CustomerID
HAVING COUNT(*) > 1;
