-- Add new columns to user_profiles table if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'approval_status') THEN
        ALTER TABLE user_profiles ADD COLUMN approval_status TEXT DEFAULT 'pending' CHECK (approval_status IN ('pending', 'approved', 'rejected'));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'approved_at') THEN
        ALTER TABLE user_profiles ADD COLUMN approved_at TIMESTAMPTZ;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'approved_by') THEN
        ALTER TABLE user_profiles ADD COLUMN approved_by UUID REFERENCES auth.users(id);
    END IF;
END $$;

GRANT SELECT ON public.hazards TO anon, authenticated;
GRANT INSERT, UPDATE ON public.hazards TO authenticated;
GRANT SELECT ON public.official_advisories TO anon, authenticated;
GRANT INSERT, UPDATE ON public.official_advisories TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.moderation_queue TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.user_profiles TO authenticated;

CREATE OR REPLACE FUNCTION public.is_agency_staff()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_profiles up
    WHERE up.id = auth.uid()
      AND up.role IN ('agency_official', 'admin')
  );
$$;

-- Policy: Users can view their own profile or agency staff can view all
DO $$
BEGIN
    BEGIN
        EXECUTE 'DROP POLICY IF EXISTS "Users can view their own profile or agency staff can view all" ON user_profiles';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
    EXECUTE 'CREATE POLICY "Users can view their own profile or agency staff can view all" ON user_profiles FOR SELECT USING (auth.uid() = id OR public.is_agency_staff())';
END $$;

-- Policy: Agency staff can view all profiles
DO $$
BEGIN
    BEGIN
        EXECUTE 'DROP POLICY IF EXISTS "Agency staff can update approval status" ON user_profiles';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
    EXECUTE 'CREATE POLICY "Agency staff can update approval status" ON user_profiles FOR UPDATE USING (public.is_agency_staff()) WITH CHECK (approval_status IN (''approved'', ''rejected'') AND approved_at IS NOT NULL AND approved_by = auth.uid())';
END $$;

-- Policy: Users can update their own profile
DO $$
BEGIN
    BEGIN
        EXECUTE 'DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
    EXECUTE 'CREATE POLICY "Users can update their own profile" ON user_profiles FOR UPDATE USING (auth.uid() = id)';
END $$;

-- Policy: Users can insert their own profile
DO $$
BEGIN
    BEGIN
        EXECUTE 'DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
    EXECUTE 'CREATE POLICY "Users can insert their own profile" ON user_profiles FOR INSERT WITH CHECK (auth.uid() = id)';
END $$;