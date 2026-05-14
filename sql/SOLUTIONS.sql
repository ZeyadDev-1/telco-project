-- 1.1 List customers subscribed to 'Kobiye Destek'
/*
  This query starts from CUSTOMERS because the required output is a customer
  list, then joins to TARIFFS through the foreign key column TARIFF_ID. Filtering
  by TARIFFS.NAME keeps the query independent of the numeric tariff id and makes
  the business condition easy to verify. The ORDER BY uses CUSTOMER_ID so the
  output is stable and easy to compare between DBeaver runs.
*/
SELECT
  c.CUSTOMER_ID,
  c.NAME AS CUSTOMER_NAME,
  c.CITY,
  c.SIGNUP_DATE,
  t.NAME AS TARIFF_NAME,
  t.MONTHLY_FEE
FROM CUSTOMERS c
JOIN TARIFFS t
  ON t.TARIFF_ID = c.TARIFF_ID
WHERE t.NAME = 'Kobiye Destek'
ORDER BY c.CUSTOMER_ID;


-- 1.2 Find newest customer subscribed to this tariff
/*
  This query uses the same tariff join as section 1.1, but it sorts matching
  customers from the most recent SIGNUP_DATE to the oldest. CUSTOMER_ID is used
  as a secondary descending sort key so the result remains deterministic if more
  than one customer signed up on the same latest date. FETCH FIRST 1 ROW ONLY is
  Oracle-compatible and returns the single newest matching customer requested by
  the requirement.
*/
SELECT
  c.CUSTOMER_ID,
  c.NAME AS CUSTOMER_NAME,
  c.CITY,
  c.SIGNUP_DATE,
  t.NAME AS TARIFF_NAME,
  t.MONTHLY_FEE
FROM CUSTOMERS c
JOIN TARIFFS t
  ON t.TARIFF_ID = c.TARIFF_ID
WHERE t.NAME = 'Kobiye Destek'
ORDER BY c.SIGNUP_DATE DESC, c.CUSTOMER_ID DESC
FETCH FIRST 1 ROW ONLY;


-- 2.1 Tariff distribution among customers
/*
  This query groups customers by tariff so each package receives one summary
  row. A LEFT JOIN is used from TARIFFS to CUSTOMERS so tariffs with no current
  subscribers would still appear with a zero count. The percentage calculation
  uses NULLIF around the total customer count to avoid division-by-zero errors
  if the table is ever tested before customer data is loaded.
*/
SELECT
  t.TARIFF_ID,
  t.NAME AS TARIFF_NAME,
  COUNT(c.CUSTOMER_ID) AS CUSTOMER_COUNT,
  ROUND(
    100 * COUNT(c.CUSTOMER_ID)
    / NULLIF(SUM(COUNT(c.CUSTOMER_ID)) OVER (), 0),
    2
  ) AS CUSTOMER_PERCENT
FROM TARIFFS t
LEFT JOIN CUSTOMERS c
  ON c.TARIFF_ID = t.TARIFF_ID
GROUP BY
  t.TARIFF_ID,
  t.NAME
ORDER BY CUSTOMER_COUNT DESC, t.NAME;


-- 3.1 Earliest customers to sign up
/*
  This query finds the minimum SIGNUP_DATE in CUSTOMERS and returns every
  customer whose signup date matches that minimum. This approach is safer than
  assuming the lowest CUSTOMER_ID belongs to the earliest signup because the
  requirement explicitly warns that IDs and signup chronology may differ. The
  results are ordered by CUSTOMER_ID only after the earliest date has already
  been identified.
*/
SELECT
  c.CUSTOMER_ID,
  c.NAME AS CUSTOMER_NAME,
  c.CITY,
  c.SIGNUP_DATE,
  t.NAME AS TARIFF_NAME
FROM CUSTOMERS c
JOIN TARIFFS t
  ON t.TARIFF_ID = c.TARIFF_ID
WHERE c.SIGNUP_DATE = (
  SELECT MIN(c2.SIGNUP_DATE)
  FROM CUSTOMERS c2
)
ORDER BY c.CUSTOMER_ID;


-- 3.2 Distribution of earliest customers across cities
/*
  This query first isolates the earliest signup cohort using the same minimum
  SIGNUP_DATE logic as section 3.1. It then groups only that cohort by CITY so
  the distribution reflects earliest customers rather than all customers. The
  ORDER BY places the largest city groups first and then sorts alphabetically for
  readable, repeatable output.
*/
WITH earliest_customers AS (
  SELECT
    c.CUSTOMER_ID,
    c.CITY
  FROM CUSTOMERS c
  WHERE c.SIGNUP_DATE = (
    SELECT MIN(c2.SIGNUP_DATE)
    FROM CUSTOMERS c2
  )
)
SELECT
  ec.CITY,
  COUNT(ec.CUSTOMER_ID) AS EARLIEST_CUSTOMER_COUNT
FROM earliest_customers ec
GROUP BY ec.CITY
ORDER BY EARLIEST_CUSTOMER_COUNT DESC, ec.CITY;


-- 4.1 Missing monthly record customer IDs
/*
  This query uses a LEFT JOIN from CUSTOMERS to MONTHLY_STATS and keeps only
  rows where the monthly side is missing. That pattern directly answers which
  valid customers did not receive this month's usage and payment record. Tariff
  details are joined for context, but the selected columns avoid SELECT * and
  keep the missing customer identifiers clear.
*/
SELECT
  c.CUSTOMER_ID,
  c.NAME AS CUSTOMER_NAME,
  c.CITY,
  t.NAME AS TARIFF_NAME
FROM CUSTOMERS c
JOIN TARIFFS t
  ON t.TARIFF_ID = c.TARIFF_ID
LEFT JOIN MONTHLY_STATS ms
  ON ms.CUSTOMER_ID = c.CUSTOMER_ID
WHERE ms.CUSTOMER_ID IS NULL
ORDER BY c.CUSTOMER_ID;


-- 4.2 Distribution of missing customers across cities
/*
  This query reuses the missing-record detection from section 4.1 and aggregates
  the affected customers by CITY. Grouping after the LEFT JOIN filter ensures
  that only customers without MONTHLY_STATS rows contribute to the counts. The
  output is ordered by count descending so the cities with the largest missing
  record impact appear first.
*/
SELECT
  c.CITY,
  COUNT(c.CUSTOMER_ID) AS MISSING_CUSTOMER_COUNT
FROM CUSTOMERS c
LEFT JOIN MONTHLY_STATS ms
  ON ms.CUSTOMER_ID = c.CUSTOMER_ID
WHERE ms.CUSTOMER_ID IS NULL
GROUP BY c.CITY
ORDER BY MISSING_CUSTOMER_COUNT DESC, c.CITY;


-- 5.1 Customers using at least 75% of data limit
/*
  This query joins usage records to customer and tariff data so DATA_USAGE can
  be compared with the correct DATA_LIMIT for each subscriber. The filter
  requires DATA_LIMIT to be greater than zero before calculating or comparing
  the usage percentage, which avoids division-by-zero problems for zero-data
  tariffs. The calculated percentage is included in the output so the threshold
  result can be inspected easily in DBeaver.
*/
SELECT
  c.CUSTOMER_ID,
  c.NAME AS CUSTOMER_NAME,
  c.CITY,
  t.NAME AS TARIFF_NAME,
  ms.DATA_USAGE,
  t.DATA_LIMIT,
  ROUND(100 * ms.DATA_USAGE / NULLIF(t.DATA_LIMIT, 0), 2) AS DATA_USAGE_PERCENT
FROM CUSTOMERS c
JOIN TARIFFS t
  ON t.TARIFF_ID = c.TARIFF_ID
JOIN MONTHLY_STATS ms
  ON ms.CUSTOMER_ID = c.CUSTOMER_ID
WHERE t.DATA_LIMIT > 0
  AND ms.DATA_USAGE >= 0.75 * t.DATA_LIMIT
ORDER BY DATA_USAGE_PERCENT DESC, c.CUSTOMER_ID;


-- 5.2 Customers who exhausted data, minutes, and SMS
/*
  This query compares all three usage measures against their matching tariff
  limits in the same row. It uses direct >= comparisons instead of percentages,
  so zero package limits are handled without any division. The result includes
  both usage and limit columns for data, minutes, and SMS so each exhausted
  condition can be manually validated from the output.
*/
SELECT
  c.CUSTOMER_ID,
  c.NAME AS CUSTOMER_NAME,
  c.CITY,
  t.NAME AS TARIFF_NAME,
  ms.DATA_USAGE,
  t.DATA_LIMIT,
  ms.MINUTE_USAGE,
  t.MINUTE_LIMIT,
  ms.SMS_USAGE,
  t.SMS_LIMIT
FROM CUSTOMERS c
JOIN TARIFFS t
  ON t.TARIFF_ID = c.TARIFF_ID
JOIN MONTHLY_STATS ms
  ON ms.CUSTOMER_ID = c.CUSTOMER_ID
WHERE ms.DATA_USAGE >= t.DATA_LIMIT
  AND ms.MINUTE_USAGE >= t.MINUTE_LIMIT
  AND ms.SMS_USAGE >= t.SMS_LIMIT
ORDER BY c.CUSTOMER_ID;


-- 6.1 Customers with unpaid fees
/*
  This query treats PAYMENT_STATUS = 'UNPAID' as the unpaid-fee condition
  because payment state is stored in MONTHLY_STATS. It joins back to CUSTOMERS
  and TARIFFS so the output identifies the subscriber and the fee amount that is
  associated with the customer's package. The ordering groups the output by
  tariff and city before customer id, which makes the unpaid accounts easier to
  review operationally.
*/
SELECT
  c.CUSTOMER_ID,
  c.NAME AS CUSTOMER_NAME,
  c.CITY,
  t.NAME AS TARIFF_NAME,
  t.MONTHLY_FEE,
  ms.PAYMENT_STATUS
FROM MONTHLY_STATS ms
JOIN CUSTOMERS c
  ON c.CUSTOMER_ID = ms.CUSTOMER_ID
JOIN TARIFFS t
  ON t.TARIFF_ID = c.TARIFF_ID
WHERE ms.PAYMENT_STATUS = 'UNPAID'
ORDER BY t.NAME, c.CITY, c.CUSTOMER_ID;


-- 6.2 Distribution of payment statuses across tariffs
/*
  This query groups existing monthly records by both tariff and payment status.
  Joining through CUSTOMERS preserves the real relationship between a monthly
  usage row and its customer's tariff assignment. The percentage calculation is
  partitioned by tariff, so each payment status percentage describes its share
  within that tariff and uses NULLIF to keep the expression safe.
*/
SELECT
  t.TARIFF_ID,
  t.NAME AS TARIFF_NAME,
  ms.PAYMENT_STATUS,
  COUNT(ms.CUSTOMER_ID) AS CUSTOMER_COUNT,
  ROUND(
    100 * COUNT(ms.CUSTOMER_ID)
    / NULLIF(SUM(COUNT(ms.CUSTOMER_ID)) OVER (PARTITION BY t.TARIFF_ID), 0),
    2
  ) AS PERCENT_WITHIN_TARIFF
FROM MONTHLY_STATS ms
JOIN CUSTOMERS c
  ON c.CUSTOMER_ID = ms.CUSTOMER_ID
JOIN TARIFFS t
  ON t.TARIFF_ID = c.TARIFF_ID
GROUP BY
  t.TARIFF_ID,
  t.NAME,
  ms.PAYMENT_STATUS
ORDER BY t.TARIFF_ID, ms.PAYMENT_STATUS;

