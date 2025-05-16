-- Create a table that include ALL the dates in Mar
WITH MarDates AS (
  SELECT date
  FROM UNNEST(GENERATE_DATE_ARRAY('2022-03-01', '2022-03-31', INTERVAL 1 DAY)) AS date
),
-- As I have mentioned the the .pbix (Power BI) file, the trick for this is: for any case where a user can achieve DIAMOND status for 20 days, there are always 9 specific dates that must be included (from March 12 to March 20). That means, for a user to be eligible to win, they must first achieve DIAMOND status from March 12 to March 20—this is the necessary condition to win. This time, with SQL approach, I will primarily filter the users whose transactions can be eligile from 12 to 20 Mar, meaning this is the necessary condition to become the winners.
-- Back to the 30 days before 12 Mar, 2022:
potential_users AS (
  SELECT DISTINCT UserId FROM `customer-retention-analysis.Transactions_data.transactions_details` td
  WHERE td.Date >= '2022-02-10'
),
-- Combind users and dates in Mar:
UserDates AS (
  SELECT
    p.UserId,
    m.date
  FROM potential_users p
  CROSS JOIN MarDates m
),
ActualLoyaltyPointAdded AS (
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
),
-- Calculate the accumulated Loyalty Points for last 30 days for each day in Mar
rolling_points AS (
  SELECT
    ud.UserId,
    ud.Date,
    (
      SELECT SUM(a.ActualLoyaltyPoint)
      FROM ActualLoyaltyPointAdded a
      WHERE a.UserId = ud.UserId
        AND a.Date BETWEEN DATE_SUB(ud.Date, INTERVAL 30 DAY) AND ud.Date
    ) AS Points
  FROM UserDates ud
),
--- Find the users that have at least 20-consecutive-day streak using 'Island and Gaps' method:
filtered_days AS (
  -- Filter the dates that having accumulated points > 5000 (having DIAMOND users)
  SELECT
    UserId,
    date
  FROM rolling_points
  WHERE Points > 5000
),

numbered_days AS (
  -- Add index column 
  SELECT
    UserId,
    date,
    ROW_NUMBER() OVER (PARTITION BY UserId ORDER BY date) AS rn
  FROM filtered_days
),

grouped_days AS (
  -- Calculate the gaps between data and the index to identity the groups of consecutive days
  SELECT
    UserId,
    date,
    DATE_SUB(date, INTERVAL rn DAY) AS group_id
  FROM numbered_days
),

-- Group by UserId and group_id, count the number of days
sequence_counts AS (
  SELECT
    UserId,
    COUNT(*) AS consecutive_days
  FROM grouped_days
  GROUP BY UserId, group_id
),

-- Pick out the user with streak of 20 days
qualified_users AS (
  SELECT DISTINCT UserId
  FROM sequence_counts
  WHERE consecutive_days >= 20
),

-- Identify user with longest streak
sequence_stats AS (
  SELECT
    UserId,
    group_id,
    MIN(date) AS start_date,
    MAX(date) AS end_date,
    COUNT(*) AS consecutive_days
  FROM grouped_days
  GROUP BY UserId, group_id
),

longest_sequence_per_user AS (
  SELECT
    UserId,
    start_date,
    end_date,
    consecutive_days,
    ROW_NUMBER() OVER (ORDER BY consecutive_days DESC, UserId) AS seq_rank
  FROM sequence_stats
)

-- Display the results
SELECT 
  "Number of winners" as Metrics,
  COUNT(*) 
  FROM qualified_users AS Results
UNION ALL
SELECT 
  "User(s) with longest streak",
  UserId
FROM longest_sequence_per_user
WHERE seq_rank = 1
