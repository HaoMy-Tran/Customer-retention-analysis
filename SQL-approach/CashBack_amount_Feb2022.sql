-- Combined with the 'Loyalty benefits' table and 'Loyalty Ranking' table, add columns '%cashback'  in 'Transactions' table and calculate the total cashback cost in Feb 2022.

--- Calculate column of actual loyalty points for each transaction:
WITH ActualLoyaltyPointAdded AS (
    SELECT
        td.UserId,
        td.Date,
        td.ServiceGroup,
	    	td.GMV,
        CASE 
            WHEN FLOOR(td.GMV / 1000 * lp.PointMechanism) < lp.MaxPointPerTrans THEN 
                FLOOR(td.GMV / 1000 * lp.PointMechanism)
            ELSE 
                lp.MaxPointPerTrans
        END AS ActualLoyaltyPoint
    FROM
        customer-retention-analysis.Transactions_data.transactions_details AS td
    JOIN
        customer-retention-analysis.Transactions_data.loyalty_points AS lp
        ON td.ServiceGroup = lp.ServiceGroup
),
--- Calculate column of Loyalty Points accumulated:
AccumulatedPointsAdded AS (
SELECT
    *,
      (SELECT SUM(cte1.ActualLoyaltyPoint)
			FROM ActualLoyaltyPointAdded as cte1
			WHERE cte1.UserId = ActualLoyaltyPointAdded.UserId -- this is the same as LOOKUP function in Excel
				AND cte1.Date >= DATE_SUB(ActualLoyaltyPointAdded.Date, INTERVAL '30' DAY)
				AND cte1.Date < ActualLoyaltyPointAdded.Date
    ) AS AccumulatedPoints
FROM
    ActualLoyaltyPointAdded
),
--- Calculate column of Class for each user on the day their transactions were made:
ClassIdAdded AS (
SELECT
  *,
	CASE WHEN AccumulatedPoints BETWEEN 1 AND 999 THEN 1
			WHEN AccumulatedPoints BETWEEN 1000 AND 1999 THEN 2
			WHEN AccumulatedPoints BETWEEN 2000 AND 4999 THEN 3
			WHEN AccumulatedPoints >= 5000 THEN 4 
	END AS ClassId
FROM AccumulatedPointsAdded
),
CashBackAdded AS (
  SELECT Date,GMV, lb.CashBack
  FROM ClassIdAdded
  JOIN `customer-retention-analysis.Transactions_data.loyalty_benefits` AS lb
  ON lb.ClassId = ClassIdAdded.ClassId AND lb.ServiceGroup = ClassIdAdded.ServiceGroup
)
-- Calculate cashback cost based on the Accumulated loytalty points and service group:
SELECT 
 ROUND(
  SUM(
    CASE WHEN CashBackAdded.GMV * CashBackAdded.CashBack < 10000 THEN CashBackAdded.GMV * CashBackAdded.CashBack ELSE 10000 END
  ),2
) AS CashBackAmountInFeb2022
FROM CashBackAdded
WHERE CashBackAdded.Date BETWEEN DATE '2022-02-01' AND DATE '2022-02-28'
