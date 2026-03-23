WITH result_dupes AS (
  SELECT
    'results' AS table_name,
    CAST(event_number AS STRING) AS event_number,
    CAST(run_id AS STRING) AS run_id,
    CAST(event_date AS STRING) AS event_date,
    CAST(athlete_id AS STRING) AS athlete_id,
    CAST(finish_position AS STRING) AS key_part_1,
    CAST(NULL AS STRING) AS key_part_2,
    COUNT(*) AS duplicate_count
  FROM parkrun_data.results
  GROUP BY event_number, run_id, event_date, athlete_id, finish_position
  HAVING COUNT(*) > 1

  UNION ALL

  SELECT
    'junior_results' AS table_name,
    CAST(event_number AS STRING) AS event_number,
    CAST(run_id AS STRING) AS run_id,
    CAST(event_date AS STRING) AS event_date,
    CAST(athlete_id AS STRING) AS athlete_id,
    CAST(finish_position AS STRING) AS key_part_1,
    CAST(NULL AS STRING) AS key_part_2,
    COUNT(*) AS duplicate_count
  FROM parkrun_data.junior_results
  GROUP BY event_number, run_id, event_date, athlete_id, finish_position
  HAVING COUNT(*) > 1
),
vol_dupes AS (
  SELECT
    'volunteers' AS table_name,
    CAST(event_number AS STRING) AS event_number,
    CAST(run_id AS STRING) AS run_id,
    CAST(event_date AS STRING) AS event_date,
    CAST(athlete_id AS STRING) AS athlete_id,
    CAST(task_id AS STRING) AS key_part_1,
    CAST(roster_id AS STRING) AS key_part_2,
    COUNT(*) AS duplicate_count
  FROM parkrun_data.volunteers
  GROUP BY event_number, run_id, event_date, athlete_id, task_id, roster_id
  HAVING COUNT(*) > 1

  UNION ALL

  SELECT
    'junior_volunteers' AS table_name,
    CAST(event_number AS STRING) AS event_number,
    CAST(run_id AS STRING) AS run_id,
    CAST(event_date AS STRING) AS event_date,
    CAST(athlete_id AS STRING) AS athlete_id,
    CAST(task_id AS STRING) AS key_part_1,
    CAST(roster_id AS STRING) AS key_part_2,
    COUNT(*) AS duplicate_count
  FROM parkrun_data.junior_volunteers
  GROUP BY event_number, run_id, event_date, athlete_id, task_id, roster_id
  HAVING COUNT(*) > 1
)
SELECT *
FROM result_dupes
UNION ALL
SELECT *
FROM vol_dupes
ORDER BY table_name, duplicate_count DESC;
