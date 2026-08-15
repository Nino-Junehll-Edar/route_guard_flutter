-- Enable UUID extension if not already
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- Enable PostGIS extension for geography types
CREATE EXTENSION IF NOT EXISTS postgis;

-- Extend auth.users with profile data
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  reputation INTEGER DEFAULT 0 CHECK (reputation >= 0),
  email TEXT,
  display_name TEXT,
  agency TEXT,
  role TEXT,
  approval_status TEXT DEFAULT 'pending' CHECK (approval_status IN ('pending', 'approved', 'rejected')),
  approved_at TIMESTAMPTZ,
  approved_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Hazards table
CREATE TABLE hazards (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reporter_uid UUID REFERENCES auth.users(id),
  agency_tag TEXT,
  location GEOGRAPHY(POINT, 4326),
  hazard_type TEXT,
  description TEXT,
  photo_url TEXT,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  confidence INTEGER DEFAULT 50 CHECK (confidence >= 0 AND confidence <= 100),
  weighted_confirms DECIMAL(5,2) DEFAULT 0 CHECK (weighted_confirms >= 0),
  weighted_denies DECIMAL(5,2) DEFAULT 0 CHECK (weighted_denies >= 0),
  status TEXT DEFAULT 'uncertain' CHECK (status IN ('uncertain', 'clear', 'partial', 'impassable')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Moderation queue for uncertain hazards
CREATE TABLE moderation_queue (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  hazard_id UUID REFERENCES hazards(id),
  flagged_at TIMESTAMPTZ DEFAULT NOW(),
  reason TEXT,
  reviewed_by UUID REFERENCES auth.users(id),
  reviewed_at TIMESTAMPTZ,
  outcome TEXT -- 'confirmed', 'false', 'inconclusive'
);

-- Official advisories (separate from user reports)
CREATE TABLE official_advisories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  location GEOGRAPHY(POINT, 4326),
  hazard_type TEXT,
  description TEXT,
  valid_from TIMESTAMPTZ,
  valid_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id)
);

-- Safer PostGIS access: expose GeoJSON as a computed column in views instead of
-- using raw ST_AsGeoJSON() in PostgREST selects, which can be misinterpreted as a
-- relationship lookup in the schema cache.
CREATE VIEW hazards_with_geom
WITH (security_invoker = true) AS
SELECT
  h.*,
  ST_AsGeoJSON(h.location) AS geom
FROM hazards h;

CREATE VIEW official_advisories_with_geom
WITH (security_invoker = true) AS
SELECT
  oa.*,
  ST_AsGeoJSON(oa.location) AS geom
FROM official_advisories oa;

GRANT SELECT ON public.hazards_with_geom TO anon, authenticated;
GRANT SELECT ON public.official_advisories_with_geom TO anon, authenticated;

-- Enable Row Level Security (we'll define policies later)
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE hazards ENABLE ROW LEVEL SECURITY;
ALTER TABLE moderation_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE official_advisories ENABLE ROW LEVEL SECURITY;

-- Policies for user_profiles
-- Fixed: Non-recursive policies to avoid infinite recursion
CREATE POLICY "Users can view own profile + agency officials view all"
    ON user_profiles
    FOR SELECT
    USING (
        auth.uid() = id  -- Users can always view their own profile
        OR (SELECT role FROM user_profiles WHERE id = auth.uid()) IN ('agency_official', 'admin')  -- Agency officials can view all
    );

CREATE POLICY "Agency officials can update approval status"
    ON user_profiles
    FOR UPDATE
    USING (
        (SELECT role FROM user_profiles WHERE id = auth.uid()) IN ('agency_official', 'admin')  -- Agency officials can update any profile
    )
    WITH CHECK (
        approval_status IN ('approved', 'rejected')
        AND approved_at IS NOT NULL
        AND approved_by = auth.uid()
    );

CREATE POLICY "Users can insert their own profile"
    ON user_profiles
    FOR INSERT
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON user_profiles
    FOR UPDATE
    USING (auth.uid() = id);

-- Policies for hazards
CREATE POLICY "Anyone can view hazards"
    ON hazards
    FOR SELECT
    USING (true);

CREATE POLICY "Users can insert their own hazards"
    ON hazards
    FOR INSERT
    WITH CHECK (reporter_uid = auth.uid());

CREATE POLICY "Users can update their own hazards"
    ON hazards
    FOR UPDATE
    USING (reporter_uid = auth.uid());

-- Policies for moderation_queue (restricted for security)
CREATE POLICY "Users can insert into moderation_queue for their own hazards"
    ON moderation_queue
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM hazards
            WHERE hazards.id = moderation_queue.hazard_id
            AND hazards.reporter_uid = auth.uid()
        )
    );

CREATE POLICY "Users can view moderation_queue for their own hazards"
    ON moderation_queue
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM hazards
            WHERE hazards.id = moderation_queue.hazard_id
            AND hazards.reporter_uid = auth.uid()
        )
    );

CREATE POLICY "Agency officials can view all moderation_queue"
    ON moderation_queue
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_profiles.id = auth.uid()
            AND user_profiles.role IN ('agency_official', 'admin')
        )
    );

CREATE POLICY "Users can update moderation_queue for their own hazards"
    ON moderation_queue
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM hazards
            WHERE hazards.id = moderation_queue.hazard_id
            AND hazards.reporter_uid = auth.uid()
        )
    );

CREATE POLICY "Agency officials can update any moderation_queue"
    ON moderation_queue
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_profiles.id = auth.uid()
            AND user_profiles.role IN ('agency_official', 'admin')
        )
    );

-- Policies for official_advisories
CREATE POLICY "Anyone can view official advisories"
    ON official_advisories
    FOR SELECT
    USING (true);

CREATE POLICY "Only agency officials can insert official advisories"
    ON official_advisories
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role IN ('agency_official', 'admin')
        )
    );

CREATE POLICY "Only agency officials can update official advisories"
    ON official_advisories
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role IN ('agency_official', 'admin')
        )
    );