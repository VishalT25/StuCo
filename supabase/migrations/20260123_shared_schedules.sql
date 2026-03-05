-- Migration: Add shared_schedules table for iMessage schedule sharing
-- Date: 2026-01-23

-- Create shared_schedules table
CREATE TABLE IF NOT EXISTS shared_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    share_id TEXT UNIQUE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    schedule_id UUID NOT NULL,
    schedule_name TEXT NOT NULL,
    schedule_data JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '7 days'
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_shared_schedules_share_id ON shared_schedules(share_id);
CREATE INDEX IF NOT EXISTS idx_shared_schedules_expires_at ON shared_schedules(expires_at);
CREATE INDEX IF NOT EXISTS idx_shared_schedules_user_id ON shared_schedules(user_id);

-- Enable RLS
ALTER TABLE shared_schedules ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can create their own shares"
    ON shared_schedules FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Anyone can read non-expired shared schedules"
    ON shared_schedules FOR SELECT
    USING (expires_at > NOW());

CREATE POLICY "Users can delete their own shares"
    ON shared_schedules FOR DELETE
    USING (auth.uid() = user_id);

-- Auto-delete expired shares function
CREATE OR REPLACE FUNCTION delete_expired_shares()
RETURNS void AS $$
BEGIN
    DELETE FROM shared_schedules WHERE expires_at <= NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Note: To schedule automatic cleanup, run this in Supabase SQL Editor:
-- SELECT cron.schedule('delete-expired-shares', '0 0 * * *', 'SELECT delete_expired_shares()');
