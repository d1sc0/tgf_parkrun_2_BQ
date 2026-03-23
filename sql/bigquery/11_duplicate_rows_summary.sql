WITH d AS (
  SELECT 'results' AS table_name, COUNT(*) AS duplicate_groups
  FROM (
    SELECT 1
    FROM parkrun_data.results
    GROUP BY event_number, run_id, event_date, athlete_id, finish_position
    HAVING COUNT(*) > 1
  )
  UNION ALL
  SELECT 'junior_results' AS table_name, COUNT(*) AS duplicate_groups
  FROM (
    SELECT 1
    FROM parkrun_data.junior_results
    GROUP BY event_number, run_id, event_date, athlete_id, finish_position
    HAVING COUNT(*) > 1
  )
  UNION ALL
  SELECT 'volunteers' AS table_name, COUNT(*) AS duplicate_groups
  FROM (
    SELECT 1
    FROM parkrun_data.volunteers
    GROUP BY event_number, run_id, event_date, athlete_id, task_id, roster_id
    HAVING COUNT(*) > 1
  )
  UNION ALL
  SELECT 'junior_volunteers' AS table_name, COUNT(*) AS duplicate_groups
  FROM (
    SELECT 1
    FROM parkrun_data.junior_volunteers
    GROUP BY event_number, run_id, event_date, athlete_id, task_id, roster_id
    HAVING COUNT(*) > 1
  )
)
SELECT *
FROM d
ORDER BY table_name;
