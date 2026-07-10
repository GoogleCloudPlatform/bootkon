-- Lab challenge: backtest the revenue forecast with AI.EVALUATE.
--
-- Holds out the last two seed weeks (2026-06-11 .. 2026-06-24 = 14 days),
-- forecasts them from everything before, and scores the forecast against
-- what actually happened -- per currency, because each currency is its own
-- series. Run this in the BigQuery editor of your own project (the
-- unqualified dataset name resolves there automatically).
--
-- mape = mean absolute percentage error (lower is better);
-- rmse = root mean squared error, in the row's currency.
SELECT
  currency,
  ROUND(mean_absolute_percentage_error, 1) AS mape,
  ROUND(root_mean_squared_error, 0) AS rmse
FROM
  AI.EVALUATE(
    (
      SELECT order_date, currency, gross_revenue
      FROM cymbal_gold.fct_daily_revenue
      WHERE order_date < '2026-06-11'
    ),
    (
      SELECT order_date, currency, gross_revenue
      FROM cymbal_gold.fct_daily_revenue
      WHERE order_date BETWEEN '2026-06-11' AND '2026-06-24'
    ),
    data_col => 'gross_revenue',
    timestamp_col => 'order_date',
    id_cols => ['currency'],
    horizon => 14)
ORDER BY currency
