SELECT
  run_id,
  COUNT(*) AS row_count
FROM parkrun_data.junior_volunteers
GROUP BY run_id
ORDER BY run_id DESC;
