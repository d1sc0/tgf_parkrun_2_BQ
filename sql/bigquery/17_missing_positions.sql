-- List any missing positions between 1 and the highest position for each run_id/event_date
-- Identifies gaps in results data that may indicate data quality issues

WITH position_ranges AS (
  -- Get min/max positions for each run
  SELECT
    run_id,
    event_date,
    event_number,
    MIN(finish_position) as min_pos,
    MAX(finish_position) as max_pos,
    COUNT(*) as row_count
  FROM parkrun_data.results
  GROUP BY run_id, event_date, event_number
),
-- Generate all positions from 1 to max for each run
all_positions AS (
  SELECT
    pr.run_id,
    pr.event_date,
    pr.event_number,
    pos,
    pr.row_count
  FROM position_ranges pr
  CROSS JOIN UNNEST(GENERATE_ARRAY(1, pr.max_pos)) AS pos
),
-- Find which positions exist in actual data
existing_positions AS (
  SELECT DISTINCT
    run_id,
    event_date,
    finish_position as pos
  FROM parkrun_data.results
)
SELECT
  ap.run_id,
  ap.event_date,
  ap.event_number,
  ap.pos as missing_position,
  ap.row_count as total_rows_in_run
FROM all_positions ap
LEFT JOIN existing_positions ep
  ON ap.run_id = ep.run_id
  AND ap.event_date = ep.event_date
  AND ap.pos = ep.pos
WHERE ep.pos IS NULL
ORDER BY ap.event_date DESC, ap.run_id, ap.pos;
