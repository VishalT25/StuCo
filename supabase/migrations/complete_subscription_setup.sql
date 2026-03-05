-- Complete Subscription System Setup with RevenueCat Integration
-- This creates everything from scratch if it doesn't exist

-- ============================================================================
-- Step 1: Create enum types if they don't exist
-- ============================================================================

-- Create subscription_tier enum
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_tier') THEN
        CREATE TYPE subscription_tier AS ENUM ('free', 'premium', 'pro', 'founder');
    END IF;
END $$;

-- Create user_role enum
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE user_role AS ENUM ('free', 'premium', 'pro', 'founder');
    END IF;
END $$;

-- ============================================================================
-- Step 2: Create subscribers table if it doesn't exist
-- ============================================================================

CREATE TABLE IF NOT EXISTS subscribers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    stripe_customer_id TEXT,
    subscribed BOOLEAN DEFAULT false,
    subscription_tier subscription_tier DEFAULT 'free',
    role user_role DEFAULT 'free',
    subscription_end TEXT,
    revenuecat_customer_id TEXT,
    last_entitlement_check TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

-- ============================================================================
-- Step 3: Add columns if table already exists but columns are missing
-- ============================================================================

-- Add RevenueCat customer ID column if missing
ALTER TABLE subscribers
ADD COLUMN IF NOT EXISTS revenuecat_customer_id TEXT;

-- Add last entitlement check timestamp if missing
ALTER TABLE subscribers
ADD COLUMN IF NOT EXISTS last_entitlement_check TIMESTAMPTZ;

-- Add subscription_tier column if missing
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'subscribers'
        AND column_name = 'subscription_tier'
    ) THEN
        ALTER TABLE subscribers ADD COLUMN subscription_tier subscription_tier DEFAULT 'free';
    END IF;
END $$;

-- Add role column if missing
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'subscribers'
        AND column_name = 'role'
    ) THEN
        ALTER TABLE subscribers ADD COLUMN role user_role DEFAULT 'free';
    END IF;
END $$;

-- ============================================================================
-- Step 4: Add comments to columns
-- ============================================================================

COMMENT ON COLUMN subscribers.revenuecat_customer_id IS
'RevenueCat customer ID (app_user_id) for linking purchases to user account';

COMMENT ON COLUMN subscribers.last_entitlement_check IS
'Timestamp of last entitlement verification from RevenueCat SDK';

COMMENT ON COLUMN subscribers.subscription_tier IS
'Current subscription tier: free, premium, pro, or founder';

COMMENT ON COLUMN subscribers.role IS
'User role matching subscription tier';

-- ============================================================================
-- Step 5: Create indexes for performance
-- ============================================================================

-- Index on user_id (primary lookup)
CREATE INDEX IF NOT EXISTS idx_subscribers_user_id
ON subscribers(user_id);

-- Index on RevenueCat customer ID for faster lookups
CREATE INDEX IF NOT EXISTS idx_subscribers_revenuecat_customer_id
ON subscribers(revenuecat_customer_id)
WHERE revenuecat_customer_id IS NOT NULL;

-- Composite index for user_id + subscription_tier queries
CREATE INDEX IF NOT EXISTS idx_subscribers_user_tier
ON subscribers(user_id, subscription_tier);

-- Index on email for lookups
CREATE INDEX IF NOT EXISTS idx_subscribers_email
ON subscribers(email)
WHERE email IS NOT NULL;

-- ============================================================================
-- Step 6: Enable Row Level Security (RLS)
-- ============================================================================

ALTER TABLE subscribers ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own subscription
DROP POLICY IF EXISTS "Users can view own subscription" ON subscribers;
CREATE POLICY "Users can view own subscription"
ON subscribers FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can insert their own subscription
DROP POLICY IF EXISTS "Users can insert own subscription" ON subscribers;
CREATE POLICY "Users can insert own subscription"
ON subscribers FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own subscription
DROP POLICY IF EXISTS "Users can update own subscription" ON subscribers;
CREATE POLICY "Users can update own subscription"
ON subscribers FOR UPDATE
USING (auth.uid() = user_id);

-- Policy: Service role can do anything (for RevenueCat webhook)
DROP POLICY IF EXISTS "Service role can manage all subscriptions" ON subscribers;
CREATE POLICY "Service role can manage all subscriptions"
ON subscribers FOR ALL
USING (auth.role() = 'service_role');

-- ============================================================================
-- Step 7: Create helper functions
-- ============================================================================

-- Function to get tier priority for comparison
CREATE OR REPLACE FUNCTION get_tier_priority(tier subscription_tier)
RETURNS INTEGER AS $$
BEGIN
    RETURN CASE tier
        WHEN 'free' THEN 0
        WHEN 'premium' THEN 1
        WHEN 'pro' THEN 1
        WHEN 'founder' THEN 2
        ELSE 0
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION get_tier_priority IS
'Returns priority value for subscription tier comparison. Higher = better tier.';

-- Function to check if tier has pro access
CREATE OR REPLACE FUNCTION has_pro_access(tier subscription_tier)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN tier IN ('pro', 'premium', 'founder');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION has_pro_access IS
'Returns true if subscription tier has access to pro features.';

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at
DROP TRIGGER IF EXISTS update_subscribers_updated_at ON subscribers;
CREATE TRIGGER update_subscribers_updated_at
    BEFORE UPDATE ON subscribers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- Verification Queries
-- ============================================================================

-- Verify enum types were created
SELECT typname, enumlabel
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
WHERE typname IN ('subscription_tier', 'user_role')
ORDER BY typname, enumlabel;

-- Verify subscribers table structure
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'subscribers'
ORDER BY ordinal_position;

-- Verify indexes were created
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'subscribers'
ORDER BY indexname;

-- Verify RLS is enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE tablename = 'subscribers';

-- Test helper functions
SELECT
    'free'::subscription_tier as tier,
    get_tier_priority('free'::subscription_tier) as priority,
    has_pro_access('free'::subscription_tier) as has_access
UNION ALL
SELECT
    'pro'::subscription_tier,
    get_tier_priority('pro'::subscription_tier),
    has_pro_access('pro'::subscription_tier)
UNION ALL
SELECT
    'founder'::subscription_tier,
    get_tier_priority('founder'::subscription_tier),
    has_pro_access('founder'::subscription_tier);

-- Show current subscriber count by tier (if any exist)
SELECT subscription_tier, COUNT(*) as count
FROM subscribers
GROUP BY subscription_tier;
