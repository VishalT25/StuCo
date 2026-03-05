-- Migration: Add 'pro' tier to subscription system and RevenueCat integration fields
-- Date: 2026-01-13
-- Purpose: Support new 'pro' subscription tier alongside existing 'founder' tier

-- ============================================================================
-- Step 1: Add 'pro' tier to subscription_tier enum type
-- ============================================================================

-- Note: ALTER TYPE ADD VALUE cannot run inside a transaction block
-- These commands should be run individually in the Supabase SQL Editor

DO $$
BEGIN
    -- Check if 'pro' value already exists before adding
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum
        WHERE enumlabel = 'pro'
        AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'subscription_tier')
    ) THEN
        ALTER TYPE subscription_tier ADD VALUE 'pro';
    END IF;
END $$;

-- ============================================================================
-- Step 2: Add 'pro' tier to user_role enum type
-- ============================================================================

DO $$
BEGIN
    -- Check if 'pro' value already exists before adding
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum
        WHERE enumlabel = 'pro'
        AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'user_role')
    ) THEN
        ALTER TYPE user_role ADD VALUE 'pro';
    END IF;
END $$;

-- ============================================================================
-- Step 3: Add RevenueCat integration columns to subscribers table
-- ============================================================================

-- Add RevenueCat customer ID column
ALTER TABLE subscribers
ADD COLUMN IF NOT EXISTS revenuecat_customer_id TEXT;

-- Add last entitlement check timestamp
ALTER TABLE subscribers
ADD COLUMN IF NOT EXISTS last_entitlement_check TIMESTAMPTZ;

-- Add comment to columns for documentation
COMMENT ON COLUMN subscribers.revenuecat_customer_id IS
'RevenueCat customer ID (app_user_id) for linking purchases to user account';

COMMENT ON COLUMN subscribers.last_entitlement_check IS
'Timestamp of last entitlement verification from RevenueCat SDK';

-- ============================================================================
-- Step 4: Create indexes for performance
-- ============================================================================

-- Index on RevenueCat customer ID for faster lookups
CREATE INDEX IF NOT EXISTS idx_subscribers_revenuecat_customer_id
ON subscribers(revenuecat_customer_id)
WHERE revenuecat_customer_id IS NOT NULL;

-- Composite index for user_id + subscription_tier queries
CREATE INDEX IF NOT EXISTS idx_subscribers_user_tier
ON subscribers(user_id, subscription_tier);

-- ============================================================================
-- Step 5: Optional - Migrate existing 'premium' users to 'pro' tier
-- ============================================================================

-- Uncomment the following lines if you want to migrate all existing 'premium' users to 'pro'
-- WARNING: This will permanently change user tiers. Backup data first!

-- UPDATE subscribers
-- SET subscription_tier = 'pro',
--     role = 'pro',
--     updated_at = NOW()
-- WHERE subscription_tier = 'premium';

-- COMMENT: After migration, you can optionally deprecate 'premium' tier
-- by removing it from the enum (requires additional careful migration)

-- ============================================================================
-- Step 6: Row Level Security (RLS) - Verify policies still work
-- ============================================================================

-- Verify that existing RLS policies work with new 'pro' tier
-- No changes needed - policies work with all enum values

-- ============================================================================
-- Step 7: Create helper function for tier comparison
-- ============================================================================

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

-- ============================================================================
-- Step 8: Create helper function to check pro access
-- ============================================================================

CREATE OR REPLACE FUNCTION has_pro_access(tier subscription_tier)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN tier IN ('pro', 'premium', 'founder');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION has_pro_access IS
'Returns true if subscription tier has access to pro features.';

-- ============================================================================
-- Verification Queries
-- ============================================================================

-- Verify enum values were added
SELECT enumlabel, enumtypid
FROM pg_enum
WHERE enumtypid IN (
    SELECT oid FROM pg_type
    WHERE typname IN ('subscription_tier', 'user_role')
)
ORDER BY enumtypid, enumsortorder;

-- Verify columns were added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'subscribers'
AND column_name IN ('revenuecat_customer_id', 'last_entitlement_check');

-- Verify indexes were created
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'subscribers'
AND indexname LIKE '%revenuecat%' OR indexname LIKE '%tier%';

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
