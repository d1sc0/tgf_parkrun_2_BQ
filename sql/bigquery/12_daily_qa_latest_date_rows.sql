WITH latest AS (
  SELECT 'results' AS table_name, MAX(event_date) AS latest_date FROM parkrun_data.results
  UNION ALL
  SELECT 'junior_results', MAX(event_date) FROM parkrun_data.junior_results
  UNION ALL
  SELECT 'volunteers', MAX(event_date) FROM parkrun_data.volunteers
  UNION ALL
  SELECT 'junior_volunteers', MAX(event_date) FROM parkrun_data.junior_volunteers
)
SELECT
  l.table_name,
  l.latest_date,
  CASE l.table_name
    WHEN 'results' THEN (SELECT COUNT(*) FROM parkrun_data.results r WHERE r.event_date = l.latest_date)
    WHEN 'junior_results' THEN (SELECT COUNT(*) FROM parkrun_data.junior_results r WHERE r.event_date = l.latest_date)
    WHEN 'volunteers' THEN (SELECT COUNT(*) FROM parkrun_data.volunteers v WHERE v.event_date = l.latest_date)
    WHEN 'junior_volunteers' THEN (SELECT COUNT(*) FROM parkrun_data.junior_volunteers v WHERE v.event_date = l.latest_date)
  END AS rows_on_latest_date
FROM latest l
ORDER BY l.table_name;
