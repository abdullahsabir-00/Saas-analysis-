-- ============================================================
-- Multi-tenant schema with Row-Level Security (RLS)
-- ============================================================
-- The core idea: every table that holds tenant data gets a
-- tenant_id column + an RLS policy. Postgres then enforces
-- "you can only see rows matching your tenant" AT THE DATABASE
-- LEVEL, not just in application code. Even if a developer
-- forgets a WHERE clause in a query, Postgres blocks the leak.

CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    email TEXT UNIQUE NOT NULL,
    hashed_password TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'member', -- 'admin' or 'member'
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Sample business data: metrics each tenant uploads/tracks
CREATE TABLE metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    metric_name TEXT NOT NULL,       -- e.g. "monthly_revenue"
    metric_value NUMERIC NOT NULL,
    recorded_at TIMESTAMPTZ DEFAULT now()
);

-- Store AI-generated summaries so we don't regenerate every time
CREATE TABLE ai_summaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    summary_text TEXT NOT NULL,
    generated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- Enable Row-Level Security
-- ============================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_summaries ENABLE ROW LEVEL SECURITY;

-- This setting (app.current_tenant) gets set per-request by our
-- backend right after it opens a DB connection (see database.py).
-- The policy below says: "only rows where tenant_id matches the
-- currently active tenant setting are visible."

CREATE POLICY tenant_isolation_users ON users
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

CREATE POLICY tenant_isolation_metrics ON metrics
    USING (tenant_id = current_setting('app.current_tenant')::UUID);

CREATE POLICY tenant_isolation_summaries ON ai_summaries
    USING (tenant_id = current_setting('app.current_tenant')::UUID);
