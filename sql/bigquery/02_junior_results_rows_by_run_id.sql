SELECT
  run_id,
  COUNT(*) AS row_count
FROM parkrun_data.junior_results
GROUP BY run_id
ORDER BY run_id DESC;
