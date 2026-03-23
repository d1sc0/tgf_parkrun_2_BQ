BigQuery query pack

This folder contains reusable SQL queries for row counts, athlete summaries, volunteer summaries, duplicate checks, and daily QA.

Recommended run order:

1. 12_daily_qa_latest_date_rows.sql
2. 13_daily_qa_day_over_day_deltas.sql
3. 14_daily_qa_null_rates.sql
4. 11_duplicate_rows_summary.sql
5. 10_duplicate_rows_detailed.sql (only if summary shows duplicates)

Parameter notes:

- 15_daily_qa_latest_run_completeness.sql requires:
  - @target_event_number (INT64)

Table assumptions:

- parkrun_data.results
- parkrun_data.junior_results
- parkrun_data.volunteers
- parkrun_data.junior_volunteers

If your dataset differs, update table references in each query file.
