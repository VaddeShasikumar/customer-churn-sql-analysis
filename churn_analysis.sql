/* =====================================================
   Customer Churn Analysis | SQL Server
   Dataset: IBM Telco Customer Churn (7,043 customers)
   ===================================================== */

USE ChurnDB;
GO

/* ---------- 1. DATA CLEANING ---------- */

-- Blank TotalCharges check (expected: 11)
SELECT COUNT(*) AS blank_total
FROM telco_churn
WHERE LTRIM(RTRIM(TotalCharges)) = '' OR TotalCharges IS NULL;

-- Duplicate customerID check (expected: 0 rows)
SELECT customerID, COUNT(*) AS cnt
FROM telco_churn
GROUP BY customerID
HAVING COUNT(*) > 1;

-- Clean table
SELECT
    customerID, gender, SeniorCitizen,
    CASE WHEN Partner = 1 THEN 'Yes' ELSE 'No' END AS Partner,
    CASE WHEN Dependents = 1 THEN 'Yes' ELSE 'No' END AS Dependents,
    tenure,
    CASE WHEN PhoneService = 1 THEN 'Yes' ELSE 'No' END AS PhoneService,
    MultipleLines, InternetService, OnlineSecurity, OnlineBackup,
    DeviceProtection, TechSupport, StreamingTV, StreamingMovies,
    Contract,
    CASE WHEN PaperlessBilling = 1 THEN 'Yes' ELSE 'No' END AS PaperlessBilling,
    PaymentMethod,
    CAST(MonthlyCharges AS DECIMAL(10,2)) AS MonthlyCharges,
    CAST(NULLIF(LTRIM(RTRIM(TotalCharges)), '') AS DECIMAL(10,2)) AS TotalCharges,
    CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END AS ChurnFlag
INTO telco_clean
FROM telco_churn;

/* ---------- 2. OVERALL CHURN RATE ---------- */
SELECT COUNT(*) AS total,
       SUM(ChurnFlag) AS churned,
       CAST(100.0 * SUM(ChurnFlag) / COUNT(*) AS DECIMAL(5,2)) AS churn_rate_pct
FROM telco_clean;

/* ---------- 3. CHURN BY SEGMENT (AGGREGATIONS) ---------- */

-- By contract
SELECT Contract, COUNT(*) AS customers, SUM(ChurnFlag) AS churned,
       CAST(100.0 * SUM(ChurnFlag) / COUNT(*) AS DECIMAL(5,2)) AS churn_pct
FROM telco_clean
GROUP BY Contract
ORDER BY churn_pct DESC;

-- By payment method
SELECT PaymentMethod, COUNT(*) AS customers,
       CAST(100.0 * SUM(ChurnFlag) / COUNT(*) AS DECIMAL(5,2)) AS churn_pct
FROM telco_clean
GROUP BY PaymentMethod
ORDER BY churn_pct DESC;

-- By internet service
SELECT InternetService, COUNT(*) AS customers,
       CAST(100.0 * SUM(ChurnFlag) / COUNT(*) AS DECIMAL(5,2)) AS churn_pct
FROM telco_clean
GROUP BY InternetService
ORDER BY churn_pct DESC;

-- By tenure group
SELECT CASE WHEN tenure <= 12 THEN '0-12 months'
            WHEN tenure <= 24 THEN '13-24 months'
            WHEN tenure <= 48 THEN '25-48 months'
            ELSE '49+ months' END AS tenure_group,
       COUNT(*) AS customers,
       CAST(100.0 * SUM(ChurnFlag) / COUNT(*) AS DECIMAL(5,2)) AS churn_pct
FROM telco_clean
GROUP BY CASE WHEN tenure <= 12 THEN '0-12 months'
              WHEN tenure <= 24 THEN '13-24 months'
              WHEN tenure <= 48 THEN '25-48 months'
              ELSE '49+ months' END
ORDER BY churn_pct DESC;

-- By monthly charge bucket
SELECT CASE WHEN MonthlyCharges < 35 THEN 'Low (<35)'
            WHEN MonthlyCharges < 70 THEN 'Medium (35-70)'
            ELSE 'High (70+)' END AS charge_bucket,
       COUNT(*) AS customers,
       CAST(100.0 * SUM(ChurnFlag) / COUNT(*) AS DECIMAL(5,2)) AS churn_pct
FROM telco_clean
GROUP BY CASE WHEN MonthlyCharges < 35 THEN 'Low (<35)'
              WHEN MonthlyCharges < 70 THEN 'Medium (35-70)'
              ELSE 'High (70+)' END
ORDER BY churn_pct DESC;

/* ---------- 4. CTE: HIGH-RISK SEGMENT ---------- */
WITH high_risk AS (
    SELECT *
    FROM telco_clean
    WHERE Contract = 'Month-to-month'
      AND InternetService = 'Fiber optic'
      AND PaymentMethod = 'Electronic check'
      AND tenure <= 12
)
SELECT
    (SELECT COUNT(*) FROM high_risk) AS high_risk_customers,
    (SELECT SUM(ChurnFlag) FROM high_risk) AS churned,
    CAST(100.0 * (SELECT SUM(ChurnFlag) FROM high_risk)
         / (SELECT COUNT(*) FROM high_risk) AS DECIMAL(5,2)) AS churn_pct;

/* ---------- 5. WINDOW FUNCTIONS ---------- */

-- NTILE: monthly charge quartiles vs churn
WITH ranked AS (
    SELECT customerID, MonthlyCharges, ChurnFlag,
           NTILE(4) OVER (ORDER BY MonthlyCharges) AS charge_quartile
    FROM telco_clean
)
SELECT charge_quartile, COUNT(*) AS customers,
       MIN(MonthlyCharges) AS min_charge, MAX(MonthlyCharges) AS max_charge,
       CAST(100.0 * SUM(ChurnFlag) / COUNT(*) AS DECIMAL(5,2)) AS churn_pct
FROM ranked
GROUP BY charge_quartile
ORDER BY charge_quartile;

-- AVG() OVER() + RANK(): contract comparison
WITH contract_stats AS (
    SELECT Contract,
           CAST(100.0 * SUM(ChurnFlag) / COUNT(*) AS DECIMAL(5,2)) AS churn_pct
    FROM telco_clean
    GROUP BY Contract
)
SELECT Contract, churn_pct,
       CAST(AVG(churn_pct) OVER () AS DECIMAL(5,2)) AS avg_of_contracts,
       RANK() OVER (ORDER BY churn_pct DESC) AS risk_rank
FROM contract_stats;

-- RANK() PARTITION BY: top 3 highest-charge churned customers per contract
WITH r AS (
    SELECT customerID, Contract, MonthlyCharges, tenure,
           RANK() OVER (PARTITION BY Contract ORDER BY MonthlyCharges DESC) AS rnk
    FROM telco_clean
    WHERE ChurnFlag = 1
)
SELECT * FROM r
WHERE rnk <= 3
ORDER BY Contract, rnk;