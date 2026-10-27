# Customer Churn Analysis | SQL Server

## Problem
A telecom company is losing customers. This project analyzes which customer segments churn the most so the business can target retention efforts.

## Dataset
IBM Telco Customer Churn (Kaggle), 7,043 customers, 21 columns (contract, services, billing, tenure, churn).

## Tools
SQL Server Express, SSMS

## Approach
1. Imported CSV into SQL Server, validated 7,043 rows.
2. Cleaning: found 11 blank `TotalCharges` (converted to NULL), checked duplicates (0), converted `Churn` to a 1/0 flag, built `telco_clean` table.
3. Aggregations: churn rate by contract, payment method, internet service, tenure group and monthly charge bucket.
4. CTE: defined a high-risk customer segment.
5. Window functions: `NTILE`, `AVG() OVER()`, `RANK() OVER (PARTITION BY ...)`.

## Key Findings
- Overall churn rate: **26.54%** (1,869 of 7,043).
- **Month-to-month** contracts churn at 42.71% vs 2.83% for two-year contracts. 89% of all churners are month-to-month.
- **Electronic check** users churn at 45.29% vs 15-17% for automatic payments.
- **Fiber optic** customers churn at 41.89% vs 18.96% for DSL.
- Customers in their **first 12 months** churn at 47.44% vs 9.51% after 49+ months.
- Churn peaks in the 70-90 monthly charge band (37.48%).
- **High-risk segment** (month-to-month + fiber + e-check + first year): 631 customers, **71.16% churn**, about 2.7x the overall rate.

## Recommendations
1. Offer discounts to move month-to-month customers to 1-2 year contracts.
2. Give bill credits to customers who switch from electronic check to auto-pay.
3. Run onboarding and check-ins in the first 90 days.
4. Review fiber pricing and service quality; offer loyalty discounts to long-tenure, high-bill customers.

## Files
- `churn_analysis.sql`: full cleaning and analysis script.
