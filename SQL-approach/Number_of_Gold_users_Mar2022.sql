-- Calculate the number of Gold user
-- (Important Note: 
-- Points calculated for each transaction will be expired after 30 days since the day that transaction is made
-- User's rank will be reduced or increased accordingly to the change of their accumulated loyalty points):

-- Calculate column of actual loyalty points for each transaction:
WITH ActualLoyaltyPointAdded AS (
    SELECT
        td.UserId,
        td.Date,
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
    WHERE
        td.date BETWEEN DATE '2022-03-01' AND DATE '2022-03-30'
),
-- As we dont have the information about the time when the transactions were made, the Loyalty Points for a specific day with be indentified by the transaction counted by the day before. 
-- Calculate column of Loyalty Points accumulated:
AccumulatedPointAdded AS (
  SELECT
      UserId,
      SUM(ActualLoyaltyPoint) AS AccumulatedPoint
  FROM
      ActualLoyaltyPointAdded
  GROUP BY
      UserId
)
-- Results table:
SELECT 
  'Gold' AS RankName,
  COUNT(
    IF(
      AccumulatedPoint between 2000 and 4999,1,null)) AS NumberofUsers
FROM AccumulatedPointAdded
