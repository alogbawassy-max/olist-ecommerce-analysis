-- =============================================
-- Q1. How many revenue did the company make?--
-- =============================================
SELECT 
	ROUND (SUM (oi.price + oi.freight_value),0) AS total_revenue
FROM orders AS o
JOIN order_items AS oi
ON oi.order_id = o.order_id
WHERE order_status NOT IN ('canceled','unavailable')

-- =============================================
-- Q2. What is the average order value?--
-- =============================================
SELECT ROUND (AVG (order_revenue),2) AS avg_order_value
FROM ( 
      SELECT o.order_id, SUM (oi.price + oi.freight_value)AS order_revenue
	  FROM orders AS o
	  JOIN order_items AS oi
	  ON oi.order_id = o.order_id
	  WHERE o.order_status NOT IN ('canceled', 'unavailable')
  GROUP BY o.order_id) AS order_summary
-- =============================================
--Q3. What % of customers returned?--
-- =============================================
WITH customers_orders AS (
					SELECT 
							c.customer_unique_id,
							COUNT (o.order_id) AS order_count
							FROM orders AS o
							JOIN customers AS c
							ON o.customer_id = c.customer_id
							GROUP BY c.customer_unique_id)
	SELECT 
			ROUND(
				COUNT(CASE WHEN order_count > 1 THEN 1 END)*100.0 / COUNT(*)
				,2) AS repeat_purchase_percentage
	FROM customers_orders
	
-- =============================================
-- QUICK ANALYSIS: WHY IS REPEAT RATE ONLY 3.12%?
-- =============================================
-- STEP 1: Scale Check
-- How many unique customers do we have?
SELECT COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers

-- How many total orders?
SELECT COUNT(*) AS total_orders 
FROM orders

-- =============================================
-- STEP 2: Repeat Purchase Distribution
-- How many customers ordered 1x, 2x, 3x etc?
-- =============================================
WITH customers_orders AS (
					SELECT 
							c.customer_unique_id,
							COUNT (o.order_id) AS order_count
							FROM orders AS o
							JOIN customers AS c
							ON o.customer_id = c.customer_id
							GROUP BY c.customer_unique_id)
	SELECT order_count,
		   COUNT(*) AS number_of_customers,
		   ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_customers
	FROM customers_orders
	GROUP BY order_count
	ORDER BY order_count
-- =============================================
-- STEP 3: Delivery Delay Analysis
-- Does late delivery hurt repeat purchases?
-- =============================================
WITH order_delivery AS (
    SELECT 
        o.order_id,
        c.customer_unique_id,
        CASE 
            WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date
            THEN 'On-Time' 
            ELSE 'Late' 
        END AS delivery_status
    FROM orders AS o
    JOIN customers AS c ON o.customer_id = c.customer_id
    WHERE o.order_delivered_customer_date IS NOT NULL
),
customer_order_counts AS (
    SELECT 
        customer_unique_id,
        COUNT(order_id) AS total_orders
    FROM order_delivery
    GROUP BY customer_unique_id
)
SELECT 
    od.delivery_status,
    COUNT(DISTINCT od.customer_unique_id)                                       AS total_customers,
    COUNT(CASE WHEN co.total_orders > 1 THEN 1 END)                            AS repeat_customers,
    ROUND(COUNT(CASE WHEN co.total_orders > 1 THEN 1 END) * 100.0 
          / COUNT(*), 2)                                                        AS repeat_rate_pct,
    ROUND(AVG(co.total_orders), 2)                                              AS avg_orders_per_customer
FROM order_delivery AS od
JOIN customer_order_counts AS co ON od.customer_unique_id = co.customer_unique_id
GROUP BY od.delivery_status

-- =============================================
-- Q4. Do late deliveries reduce review scores?
-- =============================================
SELECT
    CASE
        WHEN order_delivered_customer_date <= order_estimated_delivery_date 
        THEN 'On-Time'
        ELSE 'Late'
    END AS delivery_status,
    ROUND(AVG(r.review_score), 2) AS avg_review
FROM orders o
JOIN order_reviews r 
    ON o.order_id = r.order_id
WHERE order_delivered_customer_date IS NOT NULL
GROUP BY delivery_status

-- =============================================
-- Q5. Which states generate the most revenue?
-- =============================================
SELECT
    	c.customer_state,
    	SUM(oi.price + oi.freight_value) AS total_revenue
FROM orders o
JOIN customers c 
ON o.customer_id = c.customer_id
JOIN order_items oi
ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY c.customer_state
ORDER BY total_revenue DESC
LIMIT 10

