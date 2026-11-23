-- Run in the same Databricks SQL session as the solutions.
CREATE OR REPLACE TEMPORARY VIEW nba_drill_impression_load AS
SELECT *
FROM VALUES
    (1, 'I01', 'C01', 'Offer Card', 'Model',   TIMESTAMP '2026-01-05 09:00:00', TIMESTAMP '2026-01-05 11:30:00'),
    (2, 'I02', 'C01', 'Carousel',   'Model',   TIMESTAMP '2026-01-05 09:00:00', TIMESTAMP '2026-01-05 11:30:00'),
    (3, 'I03', 'C02', 'Offer Card', 'Control', TIMESTAMP '2026-01-05 09:05:00', TIMESTAMP '2026-01-05 11:30:00'),
    (4, 'I04', 'C03', 'Offer Card', 'Model',   TIMESTAMP '2026-01-05 09:10:00', TIMESTAMP '2026-01-05 11:30:00'),
    (5, 'I05', 'C02', 'Carousel',   'Control', TIMESTAMP '2026-01-05 09:20:00', TIMESTAMP '2026-01-05 11:30:00'),
    (6, 'I06', 'C09', 'Offer Card', 'Control', TIMESTAMP '2026-01-05 09:30:00', TIMESTAMP '2026-01-05 11:30:00'),
    (7, 'I01', 'C01', 'Offer Card', 'Model',   TIMESTAMP '2026-01-05 09:00:00', TIMESTAMP '2026-01-05 11:35:00'),
    (8, NULL,  'C03', 'Carousel',   'Model',   TIMESTAMP '2026-01-05 11:00:00', TIMESTAMP '2026-01-05 11:35:00')
AS sample(ingest_id, interaction_id, customer_id, placement, experiment_group, impression_at, ingested_at);

CREATE OR REPLACE TEMPORARY VIEW nba_drill_feedback AS
SELECT *
FROM VALUES
    ('F01', 'I01', 'Click'),
    ('F02', 'I01', 'Click'),
    ('F03', 'I01', 'Dismiss'),
    ('F04', 'I02', 'Click'),
    ('F05', 'I03', 'Dismiss'),
    ('F06', 'I05', 'Click'),
    ('F07', 'I09', 'Click')
AS sample(feedback_id, interaction_id, outcome);

CREATE OR REPLACE TEMPORARY VIEW nba_drill_customers AS
SELECT *
FROM VALUES ('C01', 'Auto'), ('C02', 'Fire'), ('C03', 'Auto')
AS sample(customer_id, product_line);
