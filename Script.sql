/* ================================================================
   SATD / TAWOS RESEARCH DATASET GENERATION
   PostgreSQL
   ================================================================ */


/* ================================================================
   0. HELPER FUNCTIONS
   ================================================================ */


/*
Safely convert text dates to PostgreSQL timestamp.

Instead of directly doing:
    "Creation_Date"::timestamp

we use safe_ts() because an empty or malformed date would otherwise
terminate the whole query.
*/

CREATE OR REPLACE FUNCTION public.safe_ts(p_text TEXT)
RETURNS TIMESTAMP
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN

    IF p_text IS NULL OR BTRIM(p_text) = '' THEN
        RETURN NULL;
    END IF;

    BEGIN
        RETURN p_text::TIMESTAMP;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END;

END;
$$;


/*
Safely convert change-log textual numbers into NUMERIC.
*/

CREATE OR REPLACE FUNCTION public.safe_numeric(p_text TEXT)
RETURNS NUMERIC
LANGUAGE SQL
IMMUTABLE
AS $$
    SELECT
        CASE
            WHEN p_text IS NULL
              OR BTRIM(p_text) = ''
            THEN NULL

            WHEN BTRIM(p_text)
                 ~ '^[+-]?([0-9]+(\.[0-9]*)?|\.[0-9]+)$'
            THEN BTRIM(p_text)::NUMERIC

            ELSE NULL
        END;
$$;



/* ================================================================
   0.1 PRIORITY NORMALIZATION
   ================================================================ */

CREATE OR REPLACE FUNCTION public.normalize_priority(p_priority TEXT)
RETURNS TEXT
LANGUAGE SQL
IMMUTABLE
AS $$
SELECT
    CASE

        WHEN UPPER(BTRIM(COALESCE(p_priority,'')))
             IN ('BLOCKER', 'BLOCKER - P1')
        THEN 'P1_BLOCKER'

        WHEN UPPER(BTRIM(COALESCE(p_priority,'')))
             IN ('CRITICAL', 'CRITICAL - P2')
        THEN 'P2_CRITICAL'

        WHEN UPPER(BTRIM(COALESCE(p_priority,'')))
             IN (
                 'HIGH',
                 'HIGHEST',
                 'MAJOR',
                 'MAJOR - P3'
             )
        THEN 'HIGH'

        WHEN UPPER(BTRIM(COALESCE(p_priority,'')))
             = 'MEDIUM'
        THEN 'MEDIUM'

        WHEN UPPER(BTRIM(COALESCE(p_priority,'')))
             IN (
                 'LOW',
                 'MINOR',
                 'MINOR - P4'
             )
        THEN 'LOW'

        WHEN UPPER(BTRIM(COALESCE(p_priority,'')))
             IN (
                 'LOWEST',
                 'TRIVIAL',
                 'TRIVIAL - P5'
             )
        THEN 'VERY_LOW'

        ELSE 'UNSPECIFIED'

    END;
$$;



/* ================================================================
   0.2 ISSUE TYPE NORMALIZATION
   ================================================================ */

CREATE OR REPLACE FUNCTION public.normalize_issue_type(p_type TEXT)
RETURNS TEXT
LANGUAGE SQL
IMMUTABLE
AS $$
SELECT
    CASE

        WHEN UPPER(BTRIM(COALESCE(p_type,'')))
             IN (
                 'BUG',
                 'BUILD FAILURE',
                 'INCIDENT',
                 'PROBLEM TICKET',
                 'PUBLIC SECURITY VULNERABILITY'
             )
        THEN 'DEFECT'

        WHEN UPPER(BTRIM(COALESCE(p_type,'')))
             IN (
                 'NEW FEATURE',
                 'ENHANCEMENT REQUEST',
                 'IMPROVEMENT',
                 'STORY',
                 'EPIC'
             )
        THEN 'FEATURE'

        WHEN UPPER(BTRIM(COALESCE(p_type,'')))
             IN (
                 'TASK',
                 'SUB-TASK',
                 'TECHNICAL TASK'
             )
        THEN 'TECHNICAL_WORK'

        WHEN UPPER(BTRIM(COALESCE(p_type,'')))
             IN (
                 'TEST',
                 'TEST TASK'
             )
        THEN 'TESTING'

        WHEN UPPER(BTRIM(COALESCE(p_type,'')))
             = 'DOCUMENTATION'
        THEN 'DOCUMENTATION'

        WHEN UPPER(BTRIM(COALESCE(p_type,'')))
             IN (
                 'QUESTION',
                 'INVESTIGATION',
                 'SUPPORT REQUEST',
                 'SUGGESTION',
                 'WISH'
             )
        THEN 'SUPPORT_INVESTIGATION'

        WHEN UPPER(BTRIM(COALESCE(p_type,'')))
             = 'TECHNICAL DEBT'
        THEN 'EXPLICIT_TECHNICAL_DEBT'

        WHEN UPPER(BTRIM(COALESCE(p_type,'')))
             IN (
                 'MILESTONE',
                 'RELEASE'
             )
        THEN 'PROJECT_MANAGEMENT'

        ELSE 'OTHER'

    END;
$$;



/* ================================================================
   0.3 STATUS NORMALIZATION
   ================================================================ */

CREATE OR REPLACE FUNCTION public.normalize_status_stage(p_status TEXT)
RETURNS TEXT
LANGUAGE SQL
IMMUTABLE
AS $$
SELECT
CASE

    /* ------------------------------------------------------------
       BACKLOG / INTAKE
       ------------------------------------------------------------ */

    WHEN UPPER(BTRIM(COALESCE(p_status,''))) IN
    (
        'BACKLOG',
        'LONG TERM BACKLOG',
        'SHORT TERM BACKLOG',
        'NEW',
        'OPEN',
        'RAW',
        'NEEDS TRIAGE',
        'TRIAGED',
        'READY TO GROOM',
        'GATHERING IMPACT',
        'GATHERING INTEREST',
        'UNDER CONSIDERATION'
    )
    THEN 'BACKLOG_INTAKE'


    /* ------------------------------------------------------------
       PLANNING / SCOPING
       ------------------------------------------------------------ */

    WHEN UPPER(BTRIM(COALESCE(p_status,''))) IN
    (
        'PLANNING',
        'SCOPING',
        'REFINE',
        'NEEDS DESIGN',
        'NEEDS SCHEDULING',
        'SCHEDULED',
        'PLANNED DEVELOPMENT',
        'READY FOR DEVELOPMENT',
        'READY FOR WORK',
        'SELECTED FOR DEVELOPMENT',
        'TO DO',
        'ACCEPTED'
    )
    THEN 'PLANNING'


    /* ------------------------------------------------------------
       DEVELOPMENT
       ------------------------------------------------------------ */

    WHEN UPPER(BTRIM(COALESCE(p_status,''))) IN
    (
        'IN DEVELOPMENT',
        'DEVELOPMENT IN PROGRESS',
        'IN PROGRESS',
        'TO DEVELOP',
        'DEBUGGING',
        'DEBUGGING WITH SUBMITTER',
        'AUTOMATION',
        'PATCH AVAILABLE',
        'INVESTIGATING'
    )
    THEN 'DEVELOPMENT'


    /* ------------------------------------------------------------
       REVIEW
       ------------------------------------------------------------ */

    WHEN UPPER(BTRIM(COALESCE(p_status,''))) IN
    (
        'CODE REVIEW',
        'IN CODE REVIEW',
        'IN REVIEW',
        'REVIEWING',
        'REVIEWABLE',
        'REVIEWED',
        'PEER REVIEW IN PROGRESS',
        'WAITING FOR PEER REVIEW',
        'WAITING FOR REVIEW',
        'IN CR REVIEW',
        'PULL REQUEST SUBMITTED',
        'IN PR'
    )
    THEN 'REVIEW'


    /* ------------------------------------------------------------
       TESTING
       ------------------------------------------------------------ */

    WHEN UPPER(BTRIM(COALESCE(p_status,''))) IN
    (
        'TEST',
        'TESTED',
        'TESTING IN PROGRESS',
        'IN QE TEST',
        'TO BE TESTED',
        'TO TEST',
        'WAITING FOR TESTING',
        'NEEDS VERIFICATION',
        'UNVERIFIED'
    )
    THEN 'TESTING'


    /* ------------------------------------------------------------
       BLOCKED / WAITING
       ------------------------------------------------------------ */

    WHEN UPPER(BTRIM(COALESCE(p_status,''))) IN
    (
        'BLOCKED',
        'WAITING (BLOCKED)',
        'WAITING FOR FEEDBACK',
        'WAITING FOR REPORTER',
        'WAITING FOR USER INPUT'
    )
    THEN 'BLOCKED_WAITING'


    /* ------------------------------------------------------------
       RELEASE / INTEGRATION
       ------------------------------------------------------------ */

    WHEN UPPER(BTRIM(COALESCE(p_status,''))) IN
    (
        'AWAITING MERGE',
        'NEEDS MERGE',
        'INTEGRATION REVIEW IN PROGRESS',
        'WAITING FOR INTEGRATION REVIEW',
        'AWAITING RELEASE',
        'WAITING FOR RELEASE',
        'PUBLISHED'
    )
    THEN 'RELEASE'


    /* ------------------------------------------------------------
       REWORK
       ------------------------------------------------------------ */

    WHEN UPPER(BTRIM(COALESCE(p_status,''))) IN
    (
        'REOPENED',
        'RETURNED'
    )
    THEN 'REWORK'


    /* ------------------------------------------------------------
       COMPLETED
       ------------------------------------------------------------ */

    WHEN UPPER(BTRIM(COALESCE(p_status,''))) IN
    (
        'DONE',
        'COMPLETE',
        'CLOSED',
        'RESOLVED'
    )
    THEN 'COMPLETED'


    /* ------------------------------------------------------------
       REJECTED / DEFERRED
       ------------------------------------------------------------ */

    WHEN UPPER(BTRIM(COALESCE(p_status,''))) IN
    (
        'INVALID',
        'WON''T FIX',
        'NOT BEING CONSIDERED',
        'FUTURE CONSIDERATION'
    )
    THEN 'DEFERRED_REJECTED'

    ELSE 'OTHER'

END;
$$;



/*
Workflow order is used for detecting backward transitions.

Blocked / Rework / Deferred states deliberately have no linear order.
*/

CREATE OR REPLACE FUNCTION public.status_stage_order(p_stage TEXT)
RETURNS INTEGER
LANGUAGE SQL
IMMUTABLE
AS $$
SELECT
CASE p_stage

    WHEN 'BACKLOG_INTAKE' THEN 1
    WHEN 'PLANNING'       THEN 2
    WHEN 'DEVELOPMENT'    THEN 3
    WHEN 'REVIEW'         THEN 4
    WHEN 'TESTING'        THEN 5
    WHEN 'RELEASE'        THEN 6
    WHEN 'COMPLETED'      THEN 7

    ELSE NULL

END;
$$;



/* ================================================================
   1. INDEXES
   ================================================================ */

CREATE INDEX IF NOT EXISTS idx_issue_id
ON public.issue ("ID");

CREATE INDEX IF NOT EXISTS idx_issue_project_sprint
ON public.issue ("Project_ID", "Sprint_ID");

CREATE INDEX IF NOT EXISTS idx_issue_sprint
ON public.issue ("Sprint_ID");


CREATE INDEX IF NOT EXISTS idx_sprint_id
ON public.sprint ("ID");

CREATE INDEX IF NOT EXISTS idx_sprint_project
ON public.sprint ("Project_ID");


CREATE INDEX IF NOT EXISTS idx_change_log_issue
ON public.change_log ("Issue_ID");

CREATE INDEX IF NOT EXISTS idx_change_log_issue_field
ON public.change_log ("Issue_ID", "Field");

CREATE INDEX IF NOT EXISTS idx_change_log_issue_date
ON public.change_log
(
    "Issue_ID",
    public.safe_ts("Creation_Date")
);


CREATE INDEX IF NOT EXISTS idx_comment_issue
ON public.comment ("Issue_ID");

CREATE INDEX IF NOT EXISTS idx_comment_issue_date
ON public.comment
(
    "Issue_ID",
    public.safe_ts("Creation_Date")
);



/* ================================================================
   2. CLEANED DATE VIEWS
   ================================================================ */

CREATE OR REPLACE VIEW public.v_issue_clean AS
SELECT
    i.*,

    public.safe_ts(i."Creation_Date")
        AS creation_ts,

    public.safe_ts(i."Estimation_Date")
        AS estimation_ts,

    public.safe_ts(i."Resolution_Date")
        AS resolution_ts,

    public.safe_ts(i."Last_Updated")
        AS last_updated_ts

FROM public.issue i;



CREATE OR REPLACE VIEW public.v_sprint_clean AS
SELECT
    s.*,

    public.safe_ts(s."Start_Date")
        AS start_ts,

    public.safe_ts(s."End_Date")
        AS end_ts,

    public.safe_ts(s."Activated_Date")
        AS activated_ts,

    public.safe_ts(s."Complete_Date")
        AS complete_ts

FROM public.sprint s;



CREATE OR REPLACE VIEW public.v_change_log_clean AS
SELECT
    cl.*,

    public.safe_ts(cl."Creation_Date")
        AS change_ts,

    NULLIF(
        BTRIM(
            COALESCE(
                cl."From_String",
                cl."From_Value"
            )
        ),
        ''
    ) AS from_text,

    NULLIF(
        BTRIM(
            COALESCE(
                cl."To_String",
                cl."To_Value"
            )
        ),
        ''
    ) AS to_text

FROM public.change_log cl;



CREATE OR REPLACE VIEW public.v_comment_clean AS
SELECT
    c.*,

    public.safe_ts(c."Creation_Date")
        AS comment_ts

FROM public.comment c;



/* ================================================================
   3. STATUS TRANSITION VIEW
   Used by RQ2, RQ3, RQ4
   ================================================================ */

CREATE OR REPLACE VIEW public.v_status_change_events AS
SELECT
    cl."ID" AS event_id,
    cl."Issue_ID" AS issue_id,
    cl.change_ts,
    cl."Author_ID" AS author_id,

    cl.from_text AS from_status,
    cl.to_text   AS to_status,

    public.normalize_status_stage(cl.from_text)
        AS from_stage,

    public.normalize_status_stage(cl.to_text)
        AS to_stage,

    public.status_stage_order(
        public.normalize_status_stage(cl.from_text)
    ) AS from_stage_order,

    public.status_stage_order(
        public.normalize_status_stage(cl.to_text)
    ) AS to_stage_order

FROM public.v_change_log_clean cl

WHERE LOWER(BTRIM(cl."Field")) = 'status'
  AND cl.change_ts IS NOT NULL;



/* ================================================================
   4. RECONSTRUCT INFORMATION AVAILABLE AT SPRINT START
   ================================================================ */

CREATE OR REPLACE VIEW public.v_issue_planning_state AS
SELECT
    i."ID" AS issue_id,
    i."Issue_Key" AS issue_key,

    i."Project_ID" AS project_id,
    i."Sprint_ID" AS sprint_id,

    i.creation_ts,
    s.start_ts AS sprint_start,
    s.end_ts AS sprint_end,

    /*
    Was this issue already present when the sprint started?
    */
    COALESCE(
        i.creation_ts <= s.start_ts,
        FALSE
    ) AS present_at_sprint_start,


    /* ============================================================
       PRIORITY AT SPRINT START
       ============================================================ */

    CASE
        WHEN COALESCE(priority_change.change_found, FALSE)
        THEN priority_change.initial_value
        ELSE i."Priority"
    END AS planning_priority,


    /* ============================================================
       ISSUE TYPE AT SPRINT START
       ============================================================ */

    CASE
        WHEN COALESCE(type_change.change_found, FALSE)
        THEN type_change.initial_value
        ELSE i."Type"
    END AS planning_issue_type,


    /* ============================================================
       STORY POINT AT SPRINT START
       ============================================================ */

    CASE
        WHEN COALESCE(sp_change.change_found, FALSE)
        THEN sp_change.initial_value
        ELSE i."Story_Point"
    END AS planning_story_point,


    /* ============================================================
       AGE BEFORE SPRINT START
       ============================================================ */

    CASE
        WHEN i.creation_ts IS NOT NULL
         AND i.creation_ts <= s.start_ts

        THEN EXTRACT(
                 EPOCH FROM
                 (s.start_ts - i.creation_ts)
             ) / 86400.0

        ELSE NULL
    END AS issue_age_days_at_sprint_start


FROM public.v_issue_clean i

JOIN public.v_sprint_clean s
    ON s."ID" = i."Sprint_ID"


/* First priority change after sprint start */
LEFT JOIN LATERAL
(
    SELECT
        TRUE AS change_found,
        cl.from_text AS initial_value

    FROM public.v_change_log_clean cl

    WHERE cl."Issue_ID" = i."ID"
      AND LOWER(BTRIM(cl."Field")) = 'priority'
      AND cl.change_ts >= s.start_ts

    ORDER BY
        cl.change_ts ASC,
        cl."ID" ASC

    LIMIT 1

) priority_change
ON TRUE


/* First issue-type change after sprint start */
LEFT JOIN LATERAL
(
    SELECT
        TRUE AS change_found,
        cl.from_text AS initial_value

    FROM public.v_change_log_clean cl

    WHERE cl."Issue_ID" = i."ID"
      AND LOWER(BTRIM(cl."Field")) = 'issuetype'
      AND cl.change_ts >= s.start_ts

    ORDER BY
        cl.change_ts ASC,
        cl."ID" ASC

    LIMIT 1

) type_change
ON TRUE


/* First story-point change after sprint start */
LEFT JOIN LATERAL
(
    SELECT
        TRUE AS change_found,

        public.safe_numeric(cl.from_text)
            ::DOUBLE PRECISION
            AS initial_value

    FROM public.v_change_log_clean cl

    WHERE cl."Issue_ID" = i."ID"
      AND LOWER(BTRIM(cl."Field")) = 'story points'
      AND cl.change_ts >= s.start_ts

    ORDER BY
        cl.change_ts ASC,
        cl."ID" ASC

    LIMIT 1

) sp_change
ON TRUE


WHERE i."Sprint_ID" IS NOT NULL
  AND s.start_ts IS NOT NULL
  AND s.end_ts IS NOT NULL
  AND s.end_ts > s.start_ts;



/* ================================================================
   5. NORMALIZED PLANNING INFORMATION
   ================================================================ */

CREATE OR REPLACE VIEW public.v_issue_planning_normalized AS

WITH base AS
(
    SELECT
        p.*,

        public.normalize_priority(
            p.planning_priority
        ) AS priority_group,

        public.normalize_issue_type(
            p.planning_issue_type
        ) AS issue_type_group,

        CASE
            WHEN p.planning_story_point IS NULL
              OR p.planning_story_point <= 0
            THEN 1
            ELSE 0
        END AS story_point_missing_or_zero

    FROM public.v_issue_planning_state p
),

positive_sp AS
(
    SELECT
        issue_id,

        PERCENT_RANK() OVER
        (
            PARTITION BY project_id
            ORDER BY planning_story_point
        ) AS project_sp_percentile

    FROM base

    WHERE planning_story_point > 0
)

SELECT
    b.*,

    ps.project_sp_percentile,

    CASE
        WHEN ps.project_sp_percentile IS NULL
        THEN 'UNESTIMATED'

        WHEN ps.project_sp_percentile < 0.33
        THEN 'LOW'

        WHEN ps.project_sp_percentile < 0.67
        THEN 'MEDIUM'

        ELSE 'HIGH'

    END AS relative_story_point_group

FROM base b

LEFT JOIN positive_sp ps
    ON ps.issue_id = b.issue_id;



/* ================================================================
   6. SPRINT PLANNING SIGNALS
   ================================================================ */

/*
This replaces the existing v_sprint_planning_signals with a
planning-time-safe version.

Only issues that existed when the sprint started are counted.
*/

CREATE OR REPLACE VIEW public.v_sprint_planning_signals AS
SELECT
    project_id,
    sprint_id,

    COUNT(*) AS sprint_issue_count,

    COUNT(*) FILTER
    (
        WHERE planning_story_point > 0
    ) AS estimated_issue_count,

    SUM(planning_story_point) FILTER
    (
        WHERE planning_story_point > 0
    ) AS sprint_total_story_points,

    AVG(planning_story_point) FILTER
    (
        WHERE planning_story_point > 0
    ) AS sprint_avg_story_points,

    PERCENTILE_CONT(0.5)
    WITHIN GROUP
    (
        ORDER BY planning_story_point
    )
    FILTER
    (
        WHERE planning_story_point > 0
    ) AS sprint_median_story_points,

    COUNT(*) FILTER
    (
        WHERE priority_group IN
        (
            'P1_BLOCKER',
            'P2_CRITICAL',
            'HIGH'
        )
    ) AS urgent_issue_count,

    ROUND(
        (
            COUNT(*) FILTER
            (
                WHERE priority_group IN
                (
                    'P1_BLOCKER',
                    'P2_CRITICAL',
                    'HIGH'
                )
            )
        )::NUMERIC
        /
        NULLIF(COUNT(*), 0),
        4
    ) AS urgent_issue_ratio

FROM public.v_issue_planning_normalized

WHERE present_at_sprint_start = TRUE

GROUP BY
    project_id,
    sprint_id;



/* ================================================================
   ================================================================
   RQ1
   ================================================================
   Can information available at sprint planning identify issues at
   elevated risk of subsequently exhibiting SATD?
   ================================================================
   ================================================================ */


DROP MATERIALIZED VIEW IF EXISTS
public.rq1_planning_dataset CASCADE;


CREATE MATERIALIZED VIEW public.rq1_planning_dataset AS
SELECT
    p.issue_id,
    p.issue_key,

    p.project_id,
    p.sprint_id,

    p.sprint_start,
    p.sprint_end,

    /* -------------------------
       Issue-level planning
       ------------------------- */

    p.planning_priority,
    p.priority_group,

    p.planning_issue_type,
    p.issue_type_group,

    p.planning_story_point,

    p.story_point_missing_or_zero,

    p.project_sp_percentile,
    p.relative_story_point_group,

    p.issue_age_days_at_sprint_start,

    /* -------------------------
       Sprint-level planning
       ------------------------- */

    ss.sprint_issue_count,
    ss.estimated_issue_count,

    ss.sprint_total_story_points,
    ss.sprint_avg_story_points,
    ss.sprint_median_story_points,

    ss.urgent_issue_count,
    ss.urgent_issue_ratio,

    /* -------------------------
       SATD outcome
       ------------------------- */

    sp.is_satd,
    sp.satd_type,
    sp.satd_confidence,
    sp.model_name

FROM public.v_issue_planning_normalized p

JOIN public.satd_prediction sp
    ON sp.issue_id = p.issue_id::TEXT

JOIN public.v_sprint_planning_signals ss
    ON ss.project_id = p.project_id
   AND ss.sprint_id = p.sprint_id

WHERE p.present_at_sprint_start = TRUE

/*
Avoid trivial target leakage.
*/
AND p.issue_type_group
    <> 'EXPLICIT_TECHNICAL_DEBT';



CREATE INDEX idx_rq1_project
ON public.rq1_planning_dataset(project_id);

CREATE INDEX idx_rq1_sprint
ON public.rq1_planning_dataset(sprint_id);

CREATE INDEX idx_rq1_satd
ON public.rq1_planning_dataset(is_satd);



/* ================================================================
   RQ1 BASIC OUTPUT CHECKS
   ================================================================ */


/* SATD distribution */
SELECT
    is_satd,
    COUNT(*) AS frequency,
    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM public.rq1_planning_dataset
GROUP BY is_satd
ORDER BY is_satd;


/* Priority vs SATD */
SELECT
    priority_group,
    COUNT(*) AS total_issues,

    COUNT(*) FILTER
    (
        WHERE is_satd = 1
    ) AS satd_issues,

    ROUND(
        100.0 *
        COUNT(*) FILTER (WHERE is_satd = 1)
        /
        NULLIF(COUNT(*),0),
        2
    ) AS satd_percentage

FROM public.rq1_planning_dataset

GROUP BY priority_group

ORDER BY satd_percentage DESC;


/* Issue type vs SATD */
SELECT
    issue_type_group,
    COUNT(*) AS total_issues,

    COUNT(*) FILTER
    (
        WHERE is_satd = 1
    ) AS satd_issues,

    ROUND(
        100.0 *
        COUNT(*) FILTER (WHERE is_satd = 1)
        /
        NULLIF(COUNT(*),0),
        2
    ) AS satd_percentage

FROM public.rq1_planning_dataset

GROUP BY issue_type_group

ORDER BY satd_percentage DESC;


/* Relative complexity vs SATD */
SELECT
    relative_story_point_group,
    COUNT(*) AS total_issues,

    COUNT(*) FILTER
    (
        WHERE is_satd = 1
    ) AS satd_issues,

    ROUND(
        100.0 *
        COUNT(*) FILTER (WHERE is_satd = 1)
        /
        NULLIF(COUNT(*),0),
        2
    ) AS satd_percentage

FROM public.rq1_planning_dataset

GROUP BY relative_story_point_group

ORDER BY relative_story_point_group;



/* ================================================================
   ================================================================
   RQ2
   ================================================================
   How do SATD and non-SATD issues differ in their evolution
   throughout the Agile development lifecycle?
   ================================================================
   ================================================================ */


/* ================================================================
   7. TRANSITION-LEVEL DATASET
   ================================================================ */

DROP MATERIALIZED VIEW IF EXISTS
public.rq2_transition_dataset CASCADE;


CREATE MATERIALIZED VIEW public.rq2_transition_dataset AS

SELECT
    i."ID" AS issue_id,
    i."Issue_Key" AS issue_key,

    i."Project_ID" AS project_id,
    i."Sprint_ID" AS sprint_id,

    e.event_id,
    e.change_ts,

    ROW_NUMBER() OVER
    (
        PARTITION BY i."ID"
        ORDER BY
            e.change_ts,
            e.event_id
    ) AS transition_number,

    e.from_status,
    e.to_status,

    e.from_stage,
    e.to_stage,

    e.from_stage_order,
    e.to_stage_order,

    /* -----------------------
       Backward transition
       ----------------------- */

    CASE
        WHEN e.from_stage_order IS NOT NULL
         AND e.to_stage_order IS NOT NULL
         AND e.to_stage_order < e.from_stage_order
        THEN 1
        ELSE 0
    END AS is_backward_transition,


    /* -----------------------
       Blocking
       ----------------------- */

    CASE
        WHEN e.to_stage = 'BLOCKED_WAITING'
        THEN 1
        ELSE 0
    END AS is_blocked_entry,


    /* -----------------------
       Reopened
       ----------------------- */

    CASE
        WHEN LOWER(BTRIM(COALESCE(e.to_status,'')))
             = 'reopened'
        THEN 1
        ELSE 0
    END AS is_reopen,


    /* -----------------------
       Review rework
       ----------------------- */

    CASE
        WHEN e.from_stage = 'REVIEW'
         AND e.to_stage IN
             (
                 'DEVELOPMENT',
                 'REWORK'
             )
        THEN 1
        ELSE 0
    END AS is_review_return,


    /* -----------------------
       Testing rework
       ----------------------- */

    CASE
        WHEN e.from_stage = 'TESTING'
         AND e.to_stage IN
             (
                 'DEVELOPMENT',
                 'REWORK'
             )
        THEN 1
        ELSE 0
    END AS is_testing_return,


    CASE
        WHEN e.to_stage = 'REWORK'
        THEN 1
        ELSE 0
    END AS is_rework_entry,

    sp.is_satd,
    sp.satd_type,
    sp.satd_confidence

FROM public.v_issue_clean i

JOIN public.v_status_change_events e
    ON e.issue_id = i."ID"

JOIN public.satd_prediction sp
    ON sp.issue_id = i."ID"::TEXT

WHERE i."Sprint_ID" IS NOT NULL

AND UPPER(BTRIM(COALESCE(i."Type",'')))
    <> 'TECHNICAL DEBT';



CREATE INDEX idx_rq2_transition_issue
ON public.rq2_transition_dataset(issue_id);

CREATE INDEX idx_rq2_transition_satd
ON public.rq2_transition_dataset(is_satd);



/* ================================================================
   8. STAGE-DURATION DATASET
   ================================================================ */

/*
This measures observed time after entering a workflow state until
the next status transition.

For the final status event, Resolution_Date / Last_Updated is used.
*/

DROP MATERIALIZED VIEW IF EXISTS
public.rq2_stage_duration_dataset CASCADE;


CREATE MATERIALIZED VIEW
public.rq2_stage_duration_dataset AS

WITH ordered_events AS
(
    SELECT
        t.*,

        LEAD(t.change_ts) OVER
        (
            PARTITION BY t.issue_id
            ORDER BY
                t.change_ts,
                t.event_id
        ) AS next_change_ts

    FROM public.rq2_transition_dataset t
),

durations AS
(
    SELECT
        o.*,

        COALESCE(
            o.next_change_ts,
            i.resolution_ts,
            i.last_updated_ts
        ) AS stage_end_ts

    FROM ordered_events o

    JOIN public.v_issue_clean i
        ON i."ID" = o.issue_id
)

SELECT
    issue_id,
    issue_key,
    project_id,
    sprint_id,

    is_satd,
    satd_type,

    to_stage AS lifecycle_stage,

    COUNT(*) AS stage_entry_count,

    SUM(
        CASE
            WHEN stage_end_ts IS NOT NULL
             AND stage_end_ts >= change_ts

            THEN EXTRACT(
                     EPOCH FROM
                     (stage_end_ts - change_ts)
                 ) / 60.0

            ELSE 0
        END
    ) AS observed_minutes_in_stage

FROM durations

GROUP BY
    issue_id,
    issue_key,
    project_id,
    sprint_id,
    is_satd,
    satd_type,
    to_stage;



/* ================================================================
   9. ISSUE-LEVEL RQ2 LIFECYCLE DATASET
   ================================================================ */

DROP MATERIALIZED VIEW IF EXISTS
public.rq2_lifecycle_dataset CASCADE;


CREATE MATERIALIZED VIEW
public.rq2_lifecycle_dataset AS

WITH change_features AS
(
    SELECT
        cl."Issue_ID" AS issue_id,

        COUNT(*) AS total_change_count,


        /* ========================================================
           SCOPE
           ======================================================== */

        COUNT(*) FILTER
        (
            WHERE LOWER(BTRIM(cl."Field"))
                  = 'description'
        ) AS description_change_count,

        COUNT(*) FILTER
        (
            WHERE LOWER(BTRIM(cl."Field"))
                  = 'summary'
        ) AS summary_change_count,

        COUNT(*) FILTER
        (
            WHERE LOWER(BTRIM(cl."Field"))
                  = 'acceptance criteria'
        ) AS acceptance_criteria_change_count,

        COUNT(*) FILTER
        (
            WHERE LOWER(BTRIM(cl."Field"))
                  = 'issuetype'
        ) AS issue_type_change_count,


        /* ========================================================
           ESTIMATION
           ======================================================== */

        COUNT(*) FILTER
        (
            WHERE LOWER(BTRIM(cl."Field"))
                  = 'story points'
        ) AS story_point_change_count,

        COUNT(*) FILTER
        (
            WHERE LOWER(BTRIM(cl."Field"))
                  = 'actual story points'
        ) AS actual_story_point_change_count,

        COUNT(*) FILTER
        (
            WHERE LOWER(BTRIM(cl."Field"))
                  IN
                  (
                      'timeestimate',
                      'timeoriginalestimate'
                  )
        ) AS time_estimate_change_count,


        /* ========================================================
           OWNERSHIP / SPRINT
           ======================================================== */

        COUNT(*) FILTER
        (
            WHERE LOWER(BTRIM(cl."Field"))
                  = 'assignee'
        ) AS assignee_change_count,

        COUNT(*) FILTER
        (
            WHERE LOWER(BTRIM(cl."Field"))
                  = 'team'
        ) AS team_change_count,

        COUNT(*) FILTER
        (
            WHERE LOWER(BTRIM(cl."Field"))
                  = 'sprint'
        ) AS sprint_change_count,


        /* Priority evolution */
        COUNT(*) FILTER
        (
            WHERE LOWER(BTRIM(cl."Field"))
                  = 'priority'
        ) AS priority_change_count

    FROM public.v_change_log_clean cl

    GROUP BY cl."Issue_ID"
),

workflow_features AS
(
    SELECT
        issue_id,

        COUNT(*) AS status_transition_count,

        SUM(is_blocked_entry)
            AS blocked_count,

        SUM(is_reopen)
            AS reopen_count,

        SUM(is_review_return)
            AS review_return_count,

        SUM(is_testing_return)
            AS testing_return_count,

        SUM(is_backward_transition)
            AS backward_transition_count,

        SUM(is_rework_entry)
            AS rework_entry_count,

        MIN(change_ts)
            FILTER
            (
                WHERE is_blocked_entry = 1
            ) AS first_blocked_at,

        MIN(change_ts)
            FILTER
            (
                WHERE is_reopen = 1
            ) AS first_reopened_at,

        STRING_AGG(
            to_stage,
            ' -> '
            ORDER BY transition_number
        ) AS workflow_path

    FROM public.rq2_transition_dataset

    GROUP BY issue_id
),

stage_features AS
(
    SELECT
        issue_id,

        SUM(observed_minutes_in_stage)
            FILTER
            (
                WHERE lifecycle_stage
                      = 'PLANNING'
            ) AS planning_minutes,

        SUM(observed_minutes_in_stage)
            FILTER
            (
                WHERE lifecycle_stage
                      = 'DEVELOPMENT'
            ) AS development_minutes,

        SUM(observed_minutes_in_stage)
            FILTER
            (
                WHERE lifecycle_stage
                      = 'REVIEW'
            ) AS review_minutes,

        SUM(observed_minutes_in_stage)
            FILTER
            (
                WHERE lifecycle_stage
                      = 'TESTING'
            ) AS testing_minutes,

        SUM(observed_minutes_in_stage)
            FILTER
            (
                WHERE lifecycle_stage
                      = 'BLOCKED_WAITING'
            ) AS blocked_minutes,

        SUM(observed_minutes_in_stage)
            FILTER
            (
                WHERE lifecycle_stage
                      = 'REWORK'
            ) AS rework_minutes

    FROM public.rq2_stage_duration_dataset

    GROUP BY issue_id
)

SELECT
    i."ID" AS issue_id,
    i."Issue_Key" AS issue_key,

    i."Project_ID" AS project_id,
    i."Sprint_ID" AS sprint_id,

    i."Type" AS issue_type,
    i."Priority" AS priority,

    public.normalize_issue_type(i."Type")
        AS issue_type_group,

    public.normalize_priority(i."Priority")
        AS priority_group,

    i."Story_Point" AS story_point,


    /* ============================================================
       ISSUE LIFETIME
       ============================================================ */

    i.creation_ts,
    i.resolution_ts,
    i.last_updated_ts,

    CASE
        WHEN i.creation_ts IS NOT NULL
         AND COALESCE(
                 i.resolution_ts,
                 i.last_updated_ts
             ) IS NOT NULL
         AND COALESCE(
                 i.resolution_ts,
                 i.last_updated_ts
             ) >= i.creation_ts

        THEN EXTRACT(
                 EPOCH FROM
                 (
                     COALESCE(
                         i.resolution_ts,
                         i.last_updated_ts
                     )
                     -
                     i.creation_ts
                 )
             ) / 86400.0

        ELSE NULL
    END AS lifecycle_days,


    /* ============================================================
       SCOPE
       ============================================================ */

    COALESCE(cf.description_change_count,0)
        AS description_change_count,

    COALESCE(cf.summary_change_count,0)
        AS summary_change_count,

    COALESCE(cf.acceptance_criteria_change_count,0)
        AS acceptance_criteria_change_count,

    COALESCE(cf.issue_type_change_count,0)
        AS issue_type_change_count,

    (
        COALESCE(cf.description_change_count,0)
        +
        COALESCE(cf.summary_change_count,0)
        +
        COALESCE(cf.acceptance_criteria_change_count,0)
        +
        COALESCE(cf.issue_type_change_count,0)
    ) AS scope_change_count,


    /* ============================================================
       ESTIMATION
       ============================================================ */

    COALESCE(cf.story_point_change_count,0)
        AS story_point_change_count,

    COALESCE(cf.actual_story_point_change_count,0)
        AS actual_story_point_change_count,

    COALESCE(cf.time_estimate_change_count,0)
        AS time_estimate_change_count,

    (
        COALESCE(cf.story_point_change_count,0)
        +
        COALESCE(cf.actual_story_point_change_count,0)
        +
        COALESCE(cf.time_estimate_change_count,0)
    ) AS estimation_change_count,


    /* ============================================================
       OWNERSHIP
       ============================================================ */

    COALESCE(cf.assignee_change_count,0)
        AS assignee_change_count,

    COALESCE(cf.team_change_count,0)
        AS team_change_count,

    COALESCE(cf.sprint_change_count,0)
        AS sprint_change_count,

    COALESCE(cf.priority_change_count,0)
        AS priority_change_count,

    (
        COALESCE(cf.assignee_change_count,0)
        +
        COALESCE(cf.team_change_count,0)
        +
        COALESCE(cf.sprint_change_count,0)
    ) AS ownership_change_count,


    /* ============================================================
       WORKFLOW
       ============================================================ */

    COALESCE(wf.status_transition_count,0)
        AS status_transition_count,

    COALESCE(wf.blocked_count,0)
        AS blocked_count,

    COALESCE(wf.reopen_count,0)
        AS reopen_count,

    COALESCE(wf.review_return_count,0)
        AS review_return_count,

    COALESCE(wf.testing_return_count,0)
        AS testing_return_count,

    COALESCE(wf.backward_transition_count,0)
        AS backward_transition_count,

    COALESCE(wf.rework_entry_count,0)
        AS rework_entry_count,

    wf.first_blocked_at,
    wf.first_reopened_at,

    wf.workflow_path,


    /* ============================================================
       TIME IN WORKFLOW STAGES
       ============================================================ */

    COALESCE(sf.planning_minutes,0)
        AS planning_minutes,

    COALESCE(sf.development_minutes,0)
        AS development_minutes,

    COALESCE(sf.review_minutes,0)
        AS review_minutes,

    COALESCE(sf.testing_minutes,0)
        AS testing_minutes,

    COALESCE(sf.blocked_minutes,0)
        AS blocked_minutes,

    COALESCE(sf.rework_minutes,0)
        AS rework_minutes,


    /* ============================================================
       EXISTING TAWOS OUTCOME MEASURES
       ============================================================ */

    i."Resolution" AS resolution,

    i."Resolution_Time_Minutes"
        AS resolution_time_minutes,

    i."In_Progress_Minutes"
        AS in_progress_minutes,

    i."Total_Effort_Minutes"
        AS total_effort_minutes,

    i."Timespent"
        AS timespent,


    /* ============================================================
       SATD
       ============================================================ */

    sp.is_satd,
    sp.satd_type,
    sp.satd_confidence

FROM public.v_issue_clean i

JOIN public.satd_prediction sp
    ON sp.issue_id = i."ID"::TEXT

LEFT JOIN change_features cf
    ON cf.issue_id = i."ID"

LEFT JOIN workflow_features wf
    ON wf.issue_id = i."ID"

LEFT JOIN stage_features sf
    ON sf.issue_id = i."ID"

WHERE i."Sprint_ID" IS NOT NULL

AND UPPER(BTRIM(COALESCE(i."Type",'')))
    <> 'TECHNICAL DEBT';



CREATE INDEX idx_rq2_issue
ON public.rq2_lifecycle_dataset(issue_id);

CREATE INDEX idx_rq2_project
ON public.rq2_lifecycle_dataset(project_id);

CREATE INDEX idx_rq2_satd
ON public.rq2_lifecycle_dataset(is_satd);



/* ================================================================
   10. TRANSITION MATRIX
   ================================================================ */

CREATE OR REPLACE VIEW public.rq2_transition_matrix AS

WITH transition_counts AS
(
    SELECT
        is_satd,
        from_stage,
        to_stage,

        COUNT(*) AS transition_count

    FROM public.rq2_transition_dataset

    GROUP BY
        is_satd,
        from_stage,
        to_stage
)

SELECT
    is_satd,
    from_stage,
    to_stage,

    transition_count,

    ROUND(
        transition_count::NUMERIC
        /
        NULLIF(
            SUM(transition_count)
            OVER
            (
                PARTITION BY
                    is_satd,
                    from_stage
            ),
            0
        ),
        6
    ) AS transition_probability

FROM transition_counts;



/* ================================================================
   11. RQ2 MAIN SUMMARY TABLE
   ================================================================ */

SELECT
    is_satd,

    COUNT(*) AS issues,

    PERCENTILE_CONT(0.5)
    WITHIN GROUP
    (
        ORDER BY status_transition_count
    ) AS median_status_transitions,

    PERCENTILE_CONT(0.5)
    WITHIN GROUP
    (
        ORDER BY scope_change_count
    ) AS median_scope_changes,

    PERCENTILE_CONT(0.5)
    WITHIN GROUP
    (
        ORDER BY estimation_change_count
    ) AS median_estimation_changes,

    PERCENTILE_CONT(0.5)
    WITHIN GROUP
    (
        ORDER BY ownership_change_count
    ) AS median_ownership_changes,

    ROUND(
        100.0 *
        COUNT(*) FILTER
        (
            WHERE blocked_count > 0
        )
        /
        NULLIF(COUNT(*),0),
        2
    ) AS blocked_percentage,

    ROUND(
        100.0 *
        COUNT(*) FILTER
        (
            WHERE reopen_count > 0
        )
        /
        NULLIF(COUNT(*),0),
        2
    ) AS reopened_percentage,

    ROUND(
        100.0 *
        COUNT(*) FILTER
        (
            WHERE review_return_count > 0
        )
        /
        NULLIF(COUNT(*),0),
        2
    ) AS review_rework_percentage,

    ROUND(
        100.0 *
        COUNT(*) FILTER
        (
            WHERE testing_return_count > 0
        )
        /
        NULLIF(COUNT(*),0),
        2
    ) AS testing_rework_percentage,

    PERCENTILE_CONT(0.5)
    WITHIN GROUP
    (
        ORDER BY lifecycle_days
    ) AS median_lifecycle_days

FROM public.rq2_lifecycle_dataset

GROUP BY is_satd

ORDER BY is_satd;



/* ================================================================
   ================================================================
   COMMON CHECKPOINT INFRASTRUCTURE FOR RQ3 + RQ4
   ================================================================
   ================================================================ */


/* ================================================================
   12. ISSUE × CHECKPOINT VIEW
   ================================================================ */

CREATE OR REPLACE VIEW public.v_issue_checkpoints AS

SELECT
    p.issue_id,
    p.issue_key,

    p.project_id,
    p.sprint_id,

    p.sprint_start,
    p.sprint_end,

    cp.checkpoint,
    cp.checkpoint_fraction,
    cp.checkpoint_ts,

    1.0 - cp.checkpoint_fraction
        AS remaining_sprint_fraction,

    /* Planning features */

    p.planning_priority,
    p.priority_group,

    p.planning_issue_type,
    p.issue_type_group,

    p.planning_story_point,

    p.project_sp_percentile,
    p.relative_story_point_group,

    p.story_point_missing_or_zero,

    p.issue_age_days_at_sprint_start,

    /* Sprint features */

    ss.sprint_issue_count,
    ss.estimated_issue_count,
    ss.sprint_total_story_points,
    ss.sprint_avg_story_points,
    ss.sprint_median_story_points,
    ss.urgent_issue_count,
    ss.urgent_issue_ratio

FROM public.v_issue_planning_normalized p

JOIN public.v_sprint_planning_signals ss
    ON ss.project_id = p.project_id
   AND ss.sprint_id = p.sprint_id

CROSS JOIN LATERAL
(
    VALUES

    (
        'T0'::TEXT,
        0.00::NUMERIC,
        p.sprint_start
    ),

    (
        'T25'::TEXT,
        0.25::NUMERIC,
        p.sprint_start
        +
        (
            (p.sprint_end - p.sprint_start)
            * 0.25
        )
    ),

    (
        'T50'::TEXT,
        0.50::NUMERIC,
        p.sprint_start
        +
        (
            (p.sprint_end - p.sprint_start)
            * 0.50
        )
    ),

    (
        'T75'::TEXT,
        0.75::NUMERIC,
        p.sprint_start
        +
        (
            (p.sprint_end - p.sprint_start)
            * 0.75
        )
    ),

    (
        'T100'::TEXT,
        1.00::NUMERIC,
        p.sprint_end
    )

) cp
(
    checkpoint,
    checkpoint_fraction,
    checkpoint_ts
)

WHERE p.present_at_sprint_start = TRUE

AND p.issue_type_group
    <> 'EXPLICIT_TECHNICAL_DEBT';



/* ================================================================
   13. CHANGE FEATURES AT EACH CHECKPOINT
   ================================================================ */

CREATE OR REPLACE VIEW
public.v_checkpoint_change_features AS

SELECT
    cp.issue_id,
    cp.checkpoint,

    COUNT(cl."ID")
        AS all_change_count,


    /* ============================================================
       SCOPE
       ============================================================ */

    COUNT(cl."ID") FILTER
    (
        WHERE LOWER(BTRIM(cl."Field"))
              = 'description'
    ) AS description_change_count,

    COUNT(cl."ID") FILTER
    (
        WHERE LOWER(BTRIM(cl."Field"))
              = 'summary'
    ) AS summary_change_count,

    COUNT(cl."ID") FILTER
    (
        WHERE LOWER(BTRIM(cl."Field"))
              = 'acceptance criteria'
    ) AS acceptance_criteria_change_count,

    COUNT(cl."ID") FILTER
    (
        WHERE LOWER(BTRIM(cl."Field"))
              = 'issuetype'
    ) AS issue_type_change_count,


    /* ============================================================
       ESTIMATION
       ============================================================ */

    COUNT(cl."ID") FILTER
    (
        WHERE LOWER(BTRIM(cl."Field"))
              = 'story points'
    ) AS story_point_change_count,

    COUNT(cl."ID") FILTER
    (
        WHERE LOWER(BTRIM(cl."Field"))
              = 'actual story points'
    ) AS actual_story_point_change_count,

    COUNT(cl."ID") FILTER
    (
        WHERE LOWER(BTRIM(cl."Field"))
              IN
              (
                  'timeestimate',
                  'timeoriginalestimate'
              )
    ) AS time_estimate_change_count,


    /* ============================================================
       OWNERSHIP
       ============================================================ */

    COUNT(cl."ID") FILTER
    (
        WHERE LOWER(BTRIM(cl."Field"))
              = 'assignee'
    ) AS assignee_change_count,

    COUNT(cl."ID") FILTER
    (
        WHERE LOWER(BTRIM(cl."Field"))
              = 'team'
    ) AS team_change_count,

    COUNT(cl."ID") FILTER
    (
        WHERE LOWER(BTRIM(cl."Field"))
              = 'sprint'
    ) AS sprint_change_count,


    /* Priority changes */

    COUNT(cl."ID") FILTER
    (
        WHERE LOWER(BTRIM(cl."Field"))
              = 'priority'
    ) AS priority_change_count,


    /* Number of developers changing issue metadata */

    COUNT(DISTINCT cl."Author_ID")
        AS unique_change_authors

FROM public.v_issue_checkpoints cp

LEFT JOIN public.v_change_log_clean cl
    ON cl."Issue_ID" = cp.issue_id

   AND cl.change_ts >= cp.sprint_start

   AND cl.change_ts <= cp.checkpoint_ts

GROUP BY
    cp.issue_id,
    cp.checkpoint;



/* ================================================================
   14. WORKFLOW FEATURES AT EACH CHECKPOINT
   ================================================================ */

CREATE OR REPLACE VIEW
public.v_checkpoint_workflow_features AS

SELECT
    cp.issue_id,
    cp.checkpoint,

    COUNT(e.event_id)
        AS status_transition_count,


    COUNT(e.event_id) FILTER
    (
        WHERE e.to_stage
              = 'BLOCKED_WAITING'
    ) AS blocked_count,


    COUNT(e.event_id) FILTER
    (
        WHERE LOWER(
                  BTRIM(
                      COALESCE(
                          e.to_status,
                          ''
                      )
                  )
              ) = 'reopened'
    ) AS reopen_count,


    COUNT(e.event_id) FILTER
    (
        WHERE e.from_stage = 'REVIEW'

        AND e.to_stage IN
            (
                'DEVELOPMENT',
                'REWORK'
            )
    ) AS review_return_count,


    COUNT(e.event_id) FILTER
    (
        WHERE e.from_stage = 'TESTING'

        AND e.to_stage IN
            (
                'DEVELOPMENT',
                'REWORK'
            )
    ) AS testing_return_count,


    COUNT(e.event_id) FILTER
    (
        WHERE e.to_stage = 'REWORK'
    ) AS rework_entry_count,


    COUNT(e.event_id) FILTER
    (
        WHERE e.from_stage_order IS NOT NULL
          AND e.to_stage_order IS NOT NULL
          AND e.to_stage_order
              < e.from_stage_order
    ) AS backward_transition_count

FROM public.v_issue_checkpoints cp

LEFT JOIN public.v_status_change_events e
    ON e.issue_id = cp.issue_id

   AND e.change_ts >= cp.sprint_start

   AND e.change_ts <= cp.checkpoint_ts

GROUP BY
    cp.issue_id,
    cp.checkpoint;



/* ================================================================
   15. COMMENT FEATURES AT EACH CHECKPOINT
   ================================================================ */

CREATE OR REPLACE VIEW
public.v_checkpoint_comment_features AS

SELECT
    cp.issue_id,
    cp.checkpoint,

    COUNT(c."ID")
        AS comment_count,

    COUNT(DISTINCT c."Author_ID")
        AS unique_commenters

FROM public.v_issue_checkpoints cp

LEFT JOIN public.v_comment_clean c
    ON c."Issue_ID" = cp.issue_id

   AND c.comment_ts >= cp.sprint_start

   AND c.comment_ts <= cp.checkpoint_ts

GROUP BY
    cp.issue_id,
    cp.checkpoint;



/* ================================================================
   ================================================================
   RQ3
   ================================================================
   Which planning and in-sprint signals provide the strongest and
   most consistent indicators of SATD risk across projects?
   ================================================================
   ================================================================ */


/*
RQ3 uses T100, meaning signals observed through the entire sprint.

This is retrospective signal-ranking, not an early-warning model.
Early-warning evaluation is performed in RQ4.
*/

DROP MATERIALIZED VIEW IF EXISTS
public.rq3_signal_dataset CASCADE;


CREATE MATERIALIZED VIEW
public.rq3_signal_dataset AS

SELECT
    cp.issue_id,
    cp.issue_key,

    cp.project_id,
    cp.sprint_id,


    /* ============================================================
       PLANNING
       ============================================================ */

    cp.planning_priority,
    cp.priority_group,

    cp.planning_issue_type,
    cp.issue_type_group,

    cp.planning_story_point,
    cp.project_sp_percentile,

    cp.relative_story_point_group,
    cp.story_point_missing_or_zero,

    cp.issue_age_days_at_sprint_start,

    cp.sprint_issue_count,
    cp.estimated_issue_count,

    cp.sprint_total_story_points,
    cp.sprint_avg_story_points,
    cp.sprint_median_story_points,

    cp.urgent_issue_count,
    cp.urgent_issue_ratio,


    /* ============================================================
       SCOPE
       ============================================================ */

    COALESCE(cf.description_change_count,0)
        AS description_change_count,

    COALESCE(cf.summary_change_count,0)
        AS summary_change_count,

    COALESCE(cf.acceptance_criteria_change_count,0)
        AS acceptance_criteria_change_count,

    COALESCE(cf.issue_type_change_count,0)
        AS issue_type_change_count,

    (
        COALESCE(cf.description_change_count,0)
        +
        COALESCE(cf.summary_change_count,0)
        +
        COALESCE(cf.acceptance_criteria_change_count,0)
        +
        COALESCE(cf.issue_type_change_count,0)
    ) AS scope_instability_count,


    /* ============================================================
       ESTIMATION
       ============================================================ */

    COALESCE(cf.story_point_change_count,0)
        AS story_point_change_count,

    COALESCE(cf.actual_story_point_change_count,0)
        AS actual_story_point_change_count,

    COALESCE(cf.time_estimate_change_count,0)
        AS time_estimate_change_count,

    (
        COALESCE(cf.story_point_change_count,0)
        +
        COALESCE(cf.actual_story_point_change_count,0)
        +
        COALESCE(cf.time_estimate_change_count,0)
    ) AS estimation_instability_count,


    /* ============================================================
       OWNERSHIP
       ============================================================ */

    COALESCE(cf.assignee_change_count,0)
        AS assignee_change_count,

    COALESCE(cf.team_change_count,0)
        AS team_change_count,

    COALESCE(cf.sprint_change_count,0)
        AS sprint_change_count,

    COALESCE(cf.priority_change_count,0)
        AS priority_change_count,

    (
        COALESCE(cf.assignee_change_count,0)
        +
        COALESCE(cf.team_change_count,0)
        +
        COALESCE(cf.sprint_change_count,0)
    ) AS ownership_instability_count,


    /* ============================================================
       WORKFLOW
       ============================================================ */

    COALESCE(wf.status_transition_count,0)
        AS status_transition_count,

    COALESCE(wf.blocked_count,0)
        AS blocked_count,

    COALESCE(wf.reopen_count,0)
        AS reopen_count,

    COALESCE(wf.review_return_count,0)
        AS review_return_count,

    COALESCE(wf.testing_return_count,0)
        AS testing_return_count,

    COALESCE(wf.rework_entry_count,0)
        AS rework_entry_count,

    COALESCE(wf.backward_transition_count,0)
        AS backward_transition_count,


    /* ============================================================
       COMMUNICATION
       ============================================================ */

    COALESCE(cm.comment_count,0)
        AS comment_count,

    COALESCE(cm.unique_commenters,0)
        AS unique_commenters,

    COALESCE(cf.unique_change_authors,0)
        AS unique_change_authors,


    /* ============================================================
       SATD
       ============================================================ */

    sp.is_satd,
    sp.satd_type,
    sp.satd_confidence

FROM public.v_issue_checkpoints cp

JOIN public.satd_prediction sp
    ON sp.issue_id = cp.issue_id::TEXT

LEFT JOIN public.v_checkpoint_change_features cf
    ON cf.issue_id = cp.issue_id
   AND cf.checkpoint = cp.checkpoint

LEFT JOIN public.v_checkpoint_workflow_features wf
    ON wf.issue_id = cp.issue_id
   AND wf.checkpoint = cp.checkpoint

LEFT JOIN public.v_checkpoint_comment_features cm
    ON cm.issue_id = cp.issue_id
   AND cm.checkpoint = cp.checkpoint

WHERE cp.checkpoint = 'T100';



CREATE INDEX idx_rq3_project
ON public.rq3_signal_dataset(project_id);

CREATE INDEX idx_rq3_satd
ON public.rq3_signal_dataset(is_satd);



/* ================================================================
   ================================================================
   RQ4
   ================================================================
   How early during the sprint can signals provide a reliable
   warning of subsequent SATD?
   ================================================================
   ================================================================ */


DROP MATERIALIZED VIEW IF EXISTS
public.rq4_temporal_long_dataset CASCADE;


CREATE MATERIALIZED VIEW
public.rq4_temporal_long_dataset AS

SELECT
    cp.issue_id,
    cp.issue_key,

    cp.project_id,
    cp.sprint_id,

    cp.sprint_start,
    cp.sprint_end,

    cp.checkpoint,
    cp.checkpoint_fraction,
    cp.checkpoint_ts,

    cp.remaining_sprint_fraction,


    /* ============================================================
       PLANNING / T0 FEATURES
       ============================================================ */

    cp.planning_priority,
    cp.priority_group,

    cp.planning_issue_type,
    cp.issue_type_group,

    cp.planning_story_point,
    cp.project_sp_percentile,

    cp.relative_story_point_group,
    cp.story_point_missing_or_zero,

    cp.issue_age_days_at_sprint_start,

    cp.sprint_issue_count,
    cp.estimated_issue_count,

    cp.sprint_total_story_points,
    cp.sprint_avg_story_points,
    cp.sprint_median_story_points,

    cp.urgent_issue_count,
    cp.urgent_issue_ratio,


    /* ============================================================
       CHANGES OBSERVED UP TO CHECKPOINT
       ============================================================ */

    COALESCE(cf.all_change_count,0)
        AS all_change_count,


    /* Scope */

    COALESCE(cf.description_change_count,0)
        AS description_change_count,

    COALESCE(cf.summary_change_count,0)
        AS summary_change_count,

    COALESCE(cf.acceptance_criteria_change_count,0)
        AS acceptance_criteria_change_count,

    COALESCE(cf.issue_type_change_count,0)
        AS issue_type_change_count,

    (
        COALESCE(cf.description_change_count,0)
        +
        COALESCE(cf.summary_change_count,0)
        +
        COALESCE(cf.acceptance_criteria_change_count,0)
        +
        COALESCE(cf.issue_type_change_count,0)
    ) AS scope_instability_count,


    /* Estimation */

    COALESCE(cf.story_point_change_count,0)
        AS story_point_change_count,

    COALESCE(cf.actual_story_point_change_count,0)
        AS actual_story_point_change_count,

    COALESCE(cf.time_estimate_change_count,0)
        AS time_estimate_change_count,

    (
        COALESCE(cf.story_point_change_count,0)
        +
        COALESCE(cf.actual_story_point_change_count,0)
        +
        COALESCE(cf.time_estimate_change_count,0)
    ) AS estimation_instability_count,


    /* Ownership */

    COALESCE(cf.assignee_change_count,0)
        AS assignee_change_count,

    COALESCE(cf.team_change_count,0)
        AS team_change_count,

    COALESCE(cf.sprint_change_count,0)
        AS sprint_change_count,

    COALESCE(cf.priority_change_count,0)
        AS priority_change_count,

    (
        COALESCE(cf.assignee_change_count,0)
        +
        COALESCE(cf.team_change_count,0)
        +
        COALESCE(cf.sprint_change_count,0)
    ) AS ownership_instability_count,


    /* Workflow */

    COALESCE(wf.status_transition_count,0)
        AS status_transition_count,

    COALESCE(wf.blocked_count,0)
        AS blocked_count,

    COALESCE(wf.reopen_count,0)
        AS reopen_count,

    COALESCE(wf.review_return_count,0)
        AS review_return_count,

    COALESCE(wf.testing_return_count,0)
        AS testing_return_count,

    COALESCE(wf.rework_entry_count,0)
        AS rework_entry_count,

    COALESCE(wf.backward_transition_count,0)
        AS backward_transition_count,


    /* Collaboration */

    COALESCE(cm.comment_count,0)
        AS comment_count,

    COALESCE(cm.unique_commenters,0)
        AS unique_commenters,

    COALESCE(cf.unique_change_authors,0)
        AS unique_change_authors,


    /* ============================================================
       FINAL TARGET
       ============================================================ */

    sp.is_satd,
    sp.satd_type,
    sp.satd_confidence

FROM public.v_issue_checkpoints cp

JOIN public.satd_prediction sp
    ON sp.issue_id = cp.issue_id::TEXT

LEFT JOIN public.v_checkpoint_change_features cf
    ON cf.issue_id = cp.issue_id
   AND cf.checkpoint = cp.checkpoint

LEFT JOIN public.v_checkpoint_workflow_features wf
    ON wf.issue_id = cp.issue_id
   AND wf.checkpoint = cp.checkpoint

LEFT JOIN public.v_checkpoint_comment_features cm
    ON cm.issue_id = cp.issue_id
   AND cm.checkpoint = cp.checkpoint

/*
RQ4 excludes T100.

T100 is retained only for RQ3.
*/
WHERE cp.checkpoint IN
(
    'T0',
    'T25',
    'T50',
    'T75'
);



CREATE INDEX idx_rq4_issue
ON public.rq4_temporal_long_dataset(issue_id);

CREATE INDEX idx_rq4_project
ON public.rq4_temporal_long_dataset(project_id);

CREATE INDEX idx_rq4_checkpoint
ON public.rq4_temporal_long_dataset(checkpoint);

CREATE INDEX idx_rq4_satd
ON public.rq4_temporal_long_dataset(is_satd);



/* ================================================================
   16. INDIVIDUAL RQ4 CHECKPOINT DATASETS
   ================================================================ */

CREATE OR REPLACE VIEW public.rq4_t0_dataset AS
SELECT *
FROM public.rq4_temporal_long_dataset
WHERE checkpoint = 'T0';


CREATE OR REPLACE VIEW public.rq4_t25_dataset AS
SELECT *
FROM public.rq4_temporal_long_dataset
WHERE checkpoint = 'T25';


CREATE OR REPLACE VIEW public.rq4_t50_dataset AS
SELECT *
FROM public.rq4_temporal_long_dataset
WHERE checkpoint = 'T50';


CREATE OR REPLACE VIEW public.rq4_t75_dataset AS
SELECT *
FROM public.rq4_temporal_long_dataset
WHERE checkpoint = 'T75';



/* ================================================================
   17. DATASET SANITY CHECKS
   ================================================================ */


/* RQ1 */
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT issue_id) AS issues
FROM public.rq1_planning_dataset;


/* RQ2 */
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT issue_id) AS issues
FROM public.rq2_lifecycle_dataset;


/* RQ3 */
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT issue_id) AS issues
FROM public.rq3_signal_dataset;


/* RQ4 should normally contain about 4 rows per issue */
SELECT
    checkpoint,
    COUNT(*) AS rows,
    COUNT(DISTINCT issue_id) AS issues
FROM public.rq4_temporal_long_dataset
GROUP BY checkpoint
ORDER BY checkpoint;



/* ================================================================
   18. CHECK SATD LABEL DISTRIBUTION IN EVERY DATASET
   ================================================================ */

SELECT
    'RQ1' AS dataset,
    is_satd,
    COUNT(*) AS frequency
FROM public.rq1_planning_dataset
GROUP BY is_satd

UNION ALL

SELECT
    'RQ2',
    is_satd,
    COUNT(*)
FROM public.rq2_lifecycle_dataset
GROUP BY is_satd

UNION ALL

SELECT
    'RQ3',
    is_satd,
    COUNT(*)
FROM public.rq3_signal_dataset
GROUP BY is_satd

ORDER BY
    dataset,
    is_satd;



/* ================================================================
   19. CHECK SATD TYPE DISTRIBUTION
   ================================================================ */

SELECT
    satd_type,
    COUNT(*) AS frequency
FROM public.rq2_lifecycle_dataset
WHERE is_satd = 1
GROUP BY satd_type
ORDER BY frequency DESC;



/* ================================================================
   20. RQ4 CHECK TEMPORAL ACCUMULATION
   ================================================================ */

/*
For most issues:
T25 counts <= T50 counts <= T75 counts

If this query returns many rows, investigate.
*/

SELECT
    issue_id,

    MAX(all_change_count)
        FILTER (WHERE checkpoint = 'T25')
        AS changes_t25,

    MAX(all_change_count)
        FILTER (WHERE checkpoint = 'T50')
        AS changes_t50,

    MAX(all_change_count)
        FILTER (WHERE checkpoint = 'T75')
        AS changes_t75

FROM public.rq4_temporal_long_dataset

GROUP BY issue_id

HAVING
       MAX(all_change_count)
       FILTER (WHERE checkpoint = 'T25')

       >

       MAX(all_change_count)
       FILTER (WHERE checkpoint = 'T50')

OR

       MAX(all_change_count)
       FILTER (WHERE checkpoint = 'T50')

       >

       MAX(all_change_count)
       FILTER (WHERE checkpoint = 'T75');



/* ================================================================
   21. CHECK STORY POINT QUALITY BY PROJECT
   ================================================================ */

SELECT
    "Project_ID" AS project_id,

    COUNT(*) AS issues,

    COUNT(*) FILTER
    (
        WHERE "Story_Point" IS NULL
    ) AS null_story_points,

    COUNT(*) FILTER
    (
        WHERE "Story_Point" = 0
    ) AS zero_story_points,

    COUNT(*) FILTER
    (
        WHERE "Story_Point" > 0
    ) AS positive_story_points,

    AVG("Story_Point") FILTER
    (
        WHERE "Story_Point" > 0
    ) AS average_positive_story_point,

    PERCENTILE_CONT(0.5)
    WITHIN GROUP
    (
        ORDER BY "Story_Point"
    )
    FILTER
    (
        WHERE "Story_Point" > 0
    ) AS median_positive_story_point,

    MAX("Story_Point")
        AS max_story_point

FROM public.issue

GROUP BY "Project_ID"

ORDER BY issues DESC;