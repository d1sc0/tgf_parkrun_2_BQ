WITH unioned AS (
  SELECT 'results' AS table_name, event_date, COUNT(*) AS row_count
  FROM parkrun_data.results
  GROUP BY event_date

  UNION ALL

  SELECT 'junior_results', event_date, COUNT(*)
  FROM parkrun_data.junior_results
  GROUP BY event_date

  UNION ALL

  SELECT 'volunteers', event_date, COUNT(*)
  FROM parkrun_data.volunteers
  GROUP BY event_date

  UNION ALL

  SELECT 'junior_volunteers', event_date, COUNT(*)
  FROM parkrun_data.junior_volunteers
  GROUP BY event_date
),
ranked AS (
  SELECT
    table_name,
    event_date,
    row_count,
    row_count - LAG(row_count) OVER (PARTITION BY table_name ORDER BY event_date) AS delta_vs_prev_date,
    ROW_NUMBER() OVER (PARTITION BY table_name ORDER BY event_date DESC) AS rn
  FROM unioned
)
SELECT table_name, event_date, row_count, delta_vs_prev_date
FROM ranked
WHERE rn <= 14
ORDER BY table_name, event_date DESC;
