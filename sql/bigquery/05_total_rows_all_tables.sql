SELECT 'results' AS table_name, COUNT(*) AS total_rows FROM parkrun_data.results
UNION ALL
SELECT 'junior_results' AS table_name, COUNT(*) AS total_rows FROM parkrun_data.junior_results
UNION ALL
SELECT 'volunteers' AS table_name, COUNT(*) AS total_rows FROM parkrun_data.volunteers
UNION ALL
SELECT 'junior_volunteers' AS table_name, COUNT(*) AS total_rows FROM parkrun_data.junior_volunteers
ORDER BY table_name;
