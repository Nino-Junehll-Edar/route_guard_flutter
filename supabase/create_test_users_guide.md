# How to Create Test Users for RouteGuard Agency Dashboard

## 📋 Overview
Due to Supabase architecture limitations, the `auth.admin.create_user()` function cannot be called directly from SQL queries in the SQL editor. This guide provides two methods to create test users:

## 🛠️ Method 1: Using Supabase Dashboard UI (Recommended)

### Step-by-Step Instructions:

1. **Log in to your Supabase Dashboard**
2. **Navigate to Authentication → Users**
3. **Click "Invite user"** for each test account:

### Test User Details:

| Email | Password | Role | Agency | Status | Notes |
|-------|----------|------|--------|--------|-------|
| `agency.official@example.com` | `agency123` | Admin | City Emergency Services | Approved | Main tester for approval workflow |
| `pending.request@example.com` | `pending123` | Officer | County Fire Department | Pending | Appears in approval queue |
| `another.official@example.com` | `another123` | Officer | State Disaster Management | Approved | Additional tester |
| `public.user@example.com` | `public123` | (none) | (none) | Approved | For public app testing |

### After Inviting Users:
1. Check your email for the invitation links (if using real emails)
2. **OR** in Supabase Dashboard:
   - Go to Authentication → Users
   - Find each invited user
   - Click the three dots (...) → "Change email confirmation"
   - Set to "Confirmed" to skip email verification

## 🗄️ Method 2: Create Profiles via SQL (After Creating Auth Users)

Once you have created the auth users via the UI, run this SQL to create their profiles:

```sql
-- =============================================
-- Create Profiles for Existing Auth Users
-- =============================================
-- Run this AFTER creating the auth users via Supabase UI

-- Agency Official Profile
INSERT INTO user_profiles (
    id,
    email,
    agency,
    role,
    approval_status,
    approved_at,
    approved_by
) VALUES (
    (SELECT id FROM auth.users WHERE email = 'agency.official@example.com'),
    'agency.official@example.com',
    'City Emergency Services',
    'Admin',
    'approved',
    now(),
    (SELECT id FROM auth.users WHERE email = 'agency.official@example.com')  -- Self-approved
)
ON CONFLICT (id) DO UPDATE SET
    agency = EXCLUDED.agency,
    role = EXCLUDED.role,
    approval_status = EXCLUDED.approval_status,
    approved_at = EXCLUDED.approved_at,
    approved_by = EXCLUDED.approved_by;

-- Pending Agency Request Profile
INSERT INTO user_profiles (
    id,
    email,
    agency,
    role,
    approval_status
) VALUES (
    (SELECT id FROM auth.users WHERE email = 'pending.request@example.com'),
    'pending.request@example.com',
    'County Fire Department',
    'Officer',
    'pending'
)
ON CONFLICT (id) DO UPDATE SET
    agency = EXCLUDED.agency,
    role = EXCLUDED.role,
    approval_status = EXCLUDED.approval_status;

-- Additional Official Profile
INSERT INTO user_profiles (
    id,
    email,
    agency,
    role,
    approval_status,
    approved_at,
    approved_by
) VALUES (
    (SELECT id FROM auth.users WHERE email = 'another.official@example.com'),
    'another.official@example.com',
    'State Disaster Management',
    'Officer',
    'approved',
    now(),
    (SELECT id FROM auth.users WHERE email = 'agency.official@example.com')  -- Approved by first official
)
ON CONFLICT (id) DO UPDATE SET
    agency = EXCLUDED.agency,
    role = EXCLUDED.role,
    approval_status = EXCLUDED.approval_status,
    approved_at = EXCLUDED.approved_at,
    approved_by = EXCLUDED.approved_by;

-- Public User Profile
INSERT INTO user_profiles (
    id,
    email,
    agency,
    role,
    approval_status
) VALUES (
    (SELECT id FROM auth.users WHERE email = 'public.user@example.com'),
    'public.user@example.com',
    NULL,  -- No agency for public users
    NULL,  -- No role for public users
    'approved'  -- Public users are auto-approved
)
ON CONFLICT (id) DO UPDATE SET
    agency = EXCLUDED.agency,
    role = EXCLUDED.role,
    approval_status = EXCLUDED.approval_status;
```

## 🌪️ Create Sample Hazard for Moderation Testing

After ensuring you have a public user, run this to create a test hazard:

```sql
-- Sample Hazard for Moderation Testing
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
```

## ✅ Verification

After completing the above steps, verify in Supabase:

### 1. Auth Users Exist
- Authentication → Users → Check all 4 test emails exist and are confirmed

### 2. Profiles Created
- Table Editor → `user_profiles` → Should see 4 profiles with correct data

### 3. Sample Hazard Created
- Table Editor → `hazards` → Should see 1 flood hazard with status 'uncertain'

### 4. Test the Workflow
1. Start web app: `flutter run -d chrome`
2. Login as: `agency.official@example.com` / `agency123`
3. Go to "Requests" tab → See pending request → Approve/Reject
4. Go to "Moderation" tab → See flood hazard → Confirm/Mark as False/Inconclusive
5. Check Supabase to verify updates

## ⚠️ Important Notes

- **Passwords**: These are test passwords - change them in production or delete test users after testing
- **Email Confirmation**: For testing, you can manually confirm emails in Supabase UI
- **Service Role**: The profile INSERT SQL can be run with anon key (no service role needed)
- **Reset**: To clean up, delete users from Authentication → Users (this cascades to profiles)

## 🔗 Alternative: Use Supabase CLI (If Preferred)

If you prefer command-line and have Supabase CLI installed:

```bash
# Create users via CLI (requires service role)
supabase auth admin invite --email agency.official@example.com --project-ref YOUR_PROJECT_REF
supabase auth admin invite --email pending.request@example.com --project-ref YOUR_PROJECT_REF
# ... etc for other users
```

Then run the profile SQL as shown above.

## 📱 Testing Complete Workflow

Once test users are set up:

1. **Mobile App Users**:
   - Register via Request Access screen with test emails
   - Appear in dashboard as pending requests
   - Get approved by agency officials

2. **Agency Web Dashboard**:
   - Login with approved agency credentials
   - Approve/reject requests
   - Moderate uncertain hazards
   - Create official advisories (placeholder ready)

The agency approval workflow implementation is complete and ready for testing with this approach!