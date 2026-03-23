SELECT
  run_id,
  COUNT(*) AS row_count
FROM parkrun_data.volunteers
GROUP BY run_id
ORDER BY run_id DESC;
