-- =============================================
-- Test Users for RouteGuard Agency Dashboard
-- =============================================
-- These SQL statements create test users and their profiles.
-- NOTE: Requires service role access.
-- We set search_path to include auth schema to allow calling auth.admin.create_user.

-- =============================================
-- 1. Agency Official (Approved)
-- =============================================
DO $$
DECLARE
    v_user_id uuid;
BEGIN
    SET search_path TO auth, public;

    -- Create the auth user
    SELECT auth.admin.create_user(
        _email => 'agency.official@example.com',
        _password => 'agency123',
        _email_confirmed => true
    ) INTO v_user_id;

    -- Create the profile
    SET search_path TO public;
    INSERT INTO user_profiles (
        id,
        email,
        agency,
        role,
        approval_status,
        approved_at,
        approved_by
    ) VALUES (
        v_user_id,
        'agency.official@example.com',
        'City Emergency Services',
        'Admin',
        'approved',
        now(),
        v_user_id  -- Self-approved for demonstration purposes
    );
END $$;

-- =============================================
-- 2. Pending Agency Request
-- =============================================
DO $$
DECLARE
    v_user_id uuid;
BEGIN
    SET search_path TO auth, public;

    -- Create the auth user
    SELECT auth.admin.create_user(
        _email => 'pending.request@example.com',
        _password => 'pending123',
        _email_confirmed => true
    ) INTO v_user_id;

    -- Create the profile
    SET search_path TO public;
    INSERT INTO user_profiles (
        id,
        email,
        agency,
        role,
        approval_status
    ) VALUES (
        v_user_id,
        'pending.request@example.com',
        'County Fire Department',
        'Officer',
        'pending'
    );
END $$;

-- =============================================
-- 3. Additional Test Users (Optional)
-- =============================================
-- Example: Another agency official with different role
DO $$
DECLARE
    v_user_id uuid;
BEGIN
    SET search_path TO auth, public;

    SELECT auth.admin.create_user(
        _email => 'another.official@example.com',
        _password => 'another123',
        _email_confirmed => true
    ) INTO v_user_id;

    SET search_path TO public;
    INSERT INTO user_profiles (
        id,
        email,
        agency,
        role,
        approval_status,
        approved_at,
        approved_by
    ) VALUES (
        v_user_id,
        'another.official@example.com',
        'State Disaster Management',
        'Officer',
        'approved',
        now(),
        (SELECT id FROM user_profiles WHERE email = 'agency.official@example.com' LIMIT 1)  -- Approved by first official
    );
END $$;

-- Example: Public user (not agency) - for testing public app if needed
DO $$
DECLARE
    v_user_id uuid;
BEGIN
    SET search_path TO auth, public;

    SELECT auth.admin.create_user(
        _email => 'public.user@example.com',
        _password => 'public123',
        _email_confirmed => true
    ) INTO v_user_id;

    SET search_path TO public;
    INSERT INTO user_profiles (
        id,
        email,
        agency,
        role,
        approval_status
    ) VALUES (
        v_user_id,
        'public.user@example.com',
        NULL,  -- No agency for public users
        NULL,  -- No role for public users
        'approved'  -- Public users are auto-approved (they don't need agency access)
    );
END $$;

-- =============================================
-- 4. Sample Hazard for Moderation Testing
-- =============================================
INSERT INTO hazards (
    id,
    reporter_uid,
    agency_tag,
    location,
    hazard_type,
    description,
    photo_url,
    confidence,
    weighted_confirms,
    weighted_denies,
    status,
    timestamp,
    created_at,
    updated_at
) VALUES (
    gen_random_uuid(),
    (SELECT id FROM user_profiles WHERE email = 'public.user@example.com' LIMIT 1),
    'Public Report',
    ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326),  -- San Francisco coordinates
    'flood',
    'Flash flooding reported on Main Street near 5th Avenue. Water levels rising rapidly.',
    'https://example.com/flood_photo.jpg',
    75,
    30.0,
    5.0,
    'uncertain',  -- This will appear in the moderation queue
    now(),
    now(),
    now()
);

-- =============================================
-- Verification Queries
-- =============================================
-- Check created users:
-- SELECT id, email, agency, role, approval_status FROM user_profiles;

-- Check auth users (service role only):
-- SELECT id, email FROM auth.users WHERE email IN ('agency.official@example.com', 'pending.request@example.com');

-- Check hazards for moderation:
-- SELECT h.id, h.hazard_type, h.description, m.id as moderation_id, m.reason
-- FROM hazards h
-- LEFT JOIN moderation_queue m ON h.id = m.hazard_id
-- WHERE h.status = 'uncertain';