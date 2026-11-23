# Databricks SQL drills

Practice Next Best Action (NBA) reporting with fictional customer and interaction IDs. These drills build from validating a source to publishing placement-level click-through rates.

Open a Databricks SQL editor query attached to a SQL warehouse. Run [setup.sql](setup.sql) in that query, then run your answers in the same editor query and session. The setup uses temporary views with inline data. Rerun setup if the session resets. Read the prompts below before opening [solutions.sql](solutions.sql), which has runnable answers and notes on common pitfalls.

| View | What one row represents |
| --- | --- |
| `nba_drill_impression_load` | One ingested record claiming to represent an offer impression |
| `nba_drill_feedback` | One feedback event associated with an interaction ID |
| `nba_drill_customers` | One synthetic customer profile |

## 1. Profile the impression feed

The intended reporting grain is one displayed offer per interaction ID. In the raw feed, test whether `interaction_id` is a valid primary key. Count rows, distinct non-null interaction IDs and customer IDs, null interaction IDs, null customer IDs, and the earliest and latest impression timestamps. List repeated non-null interaction IDs and their occurrence counts. Explain why a customer ID cannot identify an impression and what `ingest_id` identifies.

**Check your work.** 8 rows, 6 distinct non-null interaction IDs, 4 distinct customers, 1 null interaction ID, and 0 null customer IDs. I01 appears twice. Timestamps span 09:00 through 11:00 on January 5, 2026.

## 2. Diagnose join cardinality

Create a CTE with the most recently ingested row per non-null interaction ID. Use `ROW_NUMBER()` and break ingestion-time ties with the higher `ingest_id`. Before each join, predict the relationship from impressions to customer profiles and from impressions to feedback. Then compare row counts for the cleaned impressions and each left join separately. List impression IDs with no matching profile or with multiple feedback rows. Also find feedback associated with no cleaned impression.

**Check your work.** 6 cleaned impressions, 6 rows after the profile join, and 8 after the raw feedback join. I06 lacks a profile. I01 has three feedback events. F07 references an absent impression.

## 3. Build and validate a CTR report

Create an interaction-level dataset. Reuse the cleaned impressions, reduce feedback to one row per interaction, and preserve all cleaned impressions. Define a clicked impression as one with one or more Click events. Compute impressions, clicked impressions, and CTR by placement and group. CTR is clicked impressions divided by impressions, expressed as a percentage. Finally, use a second window in a separate result to find the most recent impression per customer by impression time, with the higher interaction ID breaking ties.

| Placement | Group | Impressions | Clicked impressions | CTR |
| --- | --- | ---: | ---: | ---: |
| Carousel | Control | 1 | 1 | 100% |
| Carousel | Model | 1 | 1 | 100% |
| Offer Card | Control | 2 | 0 | 0% |
| Offer Card | Model | 2 | 1 | 50% |

**Check your work.** The report totals 6 impressions and 3 clicked impressions. The latest interactions are I02 for C01, I05 for C02, I04 for C03, and I06 for C09.
