WITH base AS (
  SELECT
    athlete_id,
    first_name,
    last_name,
    event_date,
    task_name
  FROM parkrun_data.junior_volunteers
  WHERE athlete_id IS NOT NULL
),
profile AS (
  SELECT
    athlete_id,
    ARRAY_AGG(
      STRUCT(first_name, last_name)
      ORDER BY event_date DESC NULLS LAST
      LIMIT 1
    )[OFFSET(0)] AS latest_name,
    COUNT(*) AS appearances_in_junior_volunteers
  FROM base
  GROUP BY athlete_id
),
roles AS (
  SELECT
    athlete_id,
    STRING_AGG(DISTINCT TRIM(role), ', ' ORDER BY TRIM(role)) AS roles_assigned
  FROM base,
  UNNEST(SPLIT(COALESCE(task_name, ''), ',')) AS role
  WHERE TRIM(role) <> ''
  GROUP BY athlete_id
)
SELECT
  p.athlete_id,
  p.latest_name.first_name AS first_name,
  p.latest_name.last_name AS last_name,
  p.appearances_in_junior_volunteers,
  r.roles_assigned
FROM profile p
LEFT JOIN roles r USING (athlete_id)
ORDER BY p.appearances_in_junior_volunteers DESC, p.athlete_id;
