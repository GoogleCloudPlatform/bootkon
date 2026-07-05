-- Lab challenge: anomaly patrol with AI.DETECT_ANOMALIES.
--
-- The same TimesFM machinery in reverse: forecast the past, then flag actual
-- days that fall outside the prediction interval. Checks the last 60 complete
-- days of each currency's series. Run this in the BigQuery editor of your own
-- project (the unqualified dataset name resolves there automatically).
--
-- Cymbal's steady synthetic revenue should yield few flags -- possibly none,
-- which is itself the finding. Drop the `WHERE is_anomaly` filter to see the
-- per-day anomaly probabilities and bounds for every checked point.
SELECT
  currency,
  time_series_timestamp AS day,
  time_series_data AS revenue,
  ROUND(anomaly_probability, 2) AS anomaly_probability
FROM
  AI.DETECT_ANOMALIES(
    (
      SELECT order_date, currency, gross_revenue
      FROM cymbal_gold.fct_daily_revenue
      WHERE order_date < CURRENT_DATE()
    ),
    data_col => 'gross_revenue',
    timestamp_col => 'order_date',
    id_cols => ['currency'],
    target_last_n_points => 60)
WHERE is_anomaly
ORDER BY currency, day
