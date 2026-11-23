-- Exercise 1. Compare row count, key completeness, and key uniqueness.
SELECT
    COUNT(*) AS raw_rows,
    COUNT(DISTINCT interaction_id) AS distinct_interactions,
    COUNT(DISTINCT customer_id) AS distinct_customers,
    COUNT_IF(interaction_id IS NULL) AS null_interaction_rows,
    COUNT_IF(customer_id IS NULL) AS null_customer_rows,
    MIN(impression_at) AS earliest_impression,
    MAX(impression_at) AS latest_impression
FROM nba_drill_impression_load;

SELECT interaction_id, COUNT(*) AS occurrences
FROM nba_drill_impression_load
WHERE interaction_id IS NOT NULL
GROUP BY interaction_id
HAVING COUNT(*) > 1
ORDER BY interaction_id;

-- Raw grain: one ingested record. ingest_id identifies that record.
-- Reporting grain: one displayed offer per interaction.
-- interaction_id fails both null and uniqueness checks in the raw feed.
-- A customer can receive multiple offers, so customer_id repeats.
-- Pitfall: COUNT(DISTINCT column) skips NULL. Profile nulls separately.
-- Unity Catalog key constraints are informational. Run these checks yourself.

-- Exercise 2. Save the cleaned CTE as a temporary view for reuse.
CREATE OR REPLACE TEMPORARY VIEW nba_drill_impressions AS
WITH ranked_load AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY interaction_id
            ORDER BY ingested_at DESC, ingest_id DESC
        ) AS load_rank
    FROM nba_drill_impression_load
    WHERE interaction_id IS NOT NULL
)
SELECT ingest_id, interaction_id, customer_id, placement, experiment_group, impression_at
FROM ranked_load
WHERE load_rank = 1;

-- Verify the right-hand profile key is complete and unique.
SELECT
    COUNT(*) AS profile_rows,
    COUNT(DISTINCT customer_id) AS distinct_profile_keys,
    COUNT_IF(customer_id IS NULL) AS null_profile_keys
FROM nba_drill_customers;

-- Impressions to profiles: many-to-zero-or-one by customer_id.
-- Impressions to feedback: one-to-zero-or-many by interaction_id.
SELECT 'cleaned impressions' AS step, COUNT(*) AS row_count
FROM nba_drill_impressions
UNION ALL
SELECT 'profile left join', COUNT(*)
FROM nba_drill_impressions AS i
LEFT JOIN nba_drill_customers AS c ON i.customer_id = c.customer_id
UNION ALL
SELECT 'feedback left join', COUNT(*)
FROM nba_drill_impressions AS i
LEFT JOIN nba_drill_feedback AS f ON i.interaction_id = f.interaction_id;

SELECT i.interaction_id, i.customer_id
FROM nba_drill_impressions AS i
LEFT JOIN nba_drill_customers AS c ON i.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

SELECT i.interaction_id, COUNT(f.feedback_id) AS feedback_events
FROM nba_drill_impressions AS i
LEFT JOIN nba_drill_feedback AS f ON i.interaction_id = f.interaction_id
GROUP BY i.interaction_id
HAVING COUNT(f.feedback_id) > 1;

SELECT f.feedback_id, f.interaction_id
FROM nba_drill_feedback AS f
LEFT JOIN nba_drill_impressions AS i ON f.interaction_id = i.interaction_id
WHERE i.interaction_id IS NULL;

-- Pitfalls: an inner join drops unmatched impressions. COUNT(*) counts the
-- preserved left row even when there is no matching feedback event.
-- NULL interaction IDs are excluded before ranking so they cannot form
-- one misleading "interaction" partition. Track rejected rows in real feeds.

-- Exercise 3. Roll feedback up before joining.
CREATE OR REPLACE TEMPORARY VIEW nba_drill_interaction_metrics AS
WITH feedback_by_interaction AS (
    SELECT
        interaction_id,
        MAX(CASE WHEN outcome = 'Click' THEN 1 ELSE 0 END) AS clicked
    FROM nba_drill_feedback
    GROUP BY interaction_id
)
SELECT
    i.*,
    COALESCE(f.clicked, 0) AS clicked
FROM nba_drill_impressions AS i
LEFT JOIN feedback_by_interaction AS f ON i.interaction_id = f.interaction_id;

-- Reconcile the report input to the cleaned impression grain.
SELECT
    COUNT(*) AS impressions,
    COUNT(DISTINCT interaction_id) AS distinct_interactions,
    SUM(clicked) AS clicked_impressions
FROM nba_drill_interaction_metrics;

SELECT
    placement,
    experiment_group,
    COUNT(*) AS impressions,
    SUM(clicked) AS clicked_impressions,
    ROUND(100.0 * SUM(clicked) / COUNT(*), 2) AS ctr_pct
FROM nba_drill_interaction_metrics
GROUP BY placement, experiment_group
ORDER BY placement, experiment_group;

WITH ranked_impressions AS (
    SELECT
        customer_id,
        interaction_id,
        impression_at,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY impression_at DESC, interaction_id DESC
        ) AS impression_rank
    FROM nba_drill_interaction_metrics
)
SELECT customer_id, interaction_id, impression_at
FROM ranked_impressions
WHERE impression_rank = 1
ORDER BY customer_id;

-- Pitfalls: two click events on I01 count as one clicked impression.
-- Filtering the raw feedback join to Click in WHERE drops non-clicked
-- impressions and changes the CTR denominator. The latest-per-customer
-- result has a different grain and would discard valid CTR impressions.
-- A timestamp alone cannot break the tie between I01 and I02.
