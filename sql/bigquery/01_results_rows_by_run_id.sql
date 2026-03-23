SELECT
  run_id,
  COUNT(*) AS row_count
FROM parkrun_data.results
GROUP BY run_id
ORDER BY run_id DESC;
