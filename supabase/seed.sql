-- ============================================================================
-- NOBLARA SEED DATA
-- For development and testing only
-- ============================================================================

-- Note: This seed file creates test data assuming you have auth.users created
-- In practice, users are created through Supabase Auth

-- Create test users in auth.users (requires admin/service role)
-- In real usage, use Supabase Auth UI or API

-- Insert test config
INSERT INTO config (key, value, description) VALUES
  ('bootstrap_mode_enabled', 'true', 'Allow users to bypass entry gate during bootstrap')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- ============================================================================
-- TEST DATA GENERATION FUNCTIONS
-- ============================================================================

-- Function to create a test user with full profile
CREATE OR REPLACE FUNCTION create_test_user(
  p_email TEXT,
  p_gender gender_type,
  p_mode app_mode,
  p_birth_year INTEGER,
  p_city TEXT,
  p_verified BOOLEAN DEFAULT FALSE,
  p_entry_approved BOOLEAN DEFAULT FALSE
) RETURNS UUID AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Generate a deterministic UUID from email for testing
  v_user_id := uuid_generate_v5(uuid_ns_url(), p_email);

  -- Create profile
  INSERT INTO profiles (user_id, gender_claim, mode, birth_year, city, bio)
  VALUES (v_user_id, p_gender, p_mode, p_birth_year, p_city, 'Test bio for ' || p_email)
  ON CONFLICT (user_id) DO NOTHING;

  -- If verified, set up verification records
  IF p_verified THEN
    -- Add photos
    INSERT INTO photos (user_id, url, order_index, face_visible, quality_score, approved)
    VALUES
      (v_user_id, 'https://example.com/photos/' || v_user_id || '/1.jpg', 0, TRUE, 85, TRUE),
      (v_user_id, 'https://example.com/photos/' || v_user_id || '/2.jpg', 1, TRUE, 80, TRUE),
      (v_user_id, 'https://example.com/photos/' || v_user_id || '/3.jpg', 2, TRUE, 75, TRUE)
    ON CONFLICT DO NOTHING;

    -- Add Instagram
    INSERT INTO instagram (user_id, ig_username, ig_connected, ig_connected_at, ig_media_verified, ig_verified_at)
    VALUES (v_user_id, 'test_' || REPLACE(p_email, '@', '_'), TRUE, NOW(), TRUE, NOW())
    ON CONFLICT (user_id) DO NOTHING;

    -- Add gender verification
    INSERT INTO gender_verification (user_id, status, submitted_at, reviewed_at)
    VALUES (v_user_id, 'approved', NOW() - INTERVAL '1 day', NOW())
    ON CONFLICT (user_id) DO NOTHING;

    -- Update verification status
    UPDATE verifications
    SET status = 'approved', photos_approved = 3, instagram_verified = TRUE, gender_verified = TRUE
    WHERE user_id = v_user_id;
  END IF;

  -- If entry approved, set entry status
  IF p_entry_approved THEN
    UPDATE entry_status
    SET status = 'approved', admin_override = TRUE
    WHERE user_id = v_user_id;
  END IF;

  RETURN v_user_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- CREATE TEST USERS
-- ============================================================================

-- Note: In production, these would be created through Supabase Auth
-- For local testing, you may need to manually create auth.users first

/*
-- Example: Create test users (run manually with service role)

SELECT create_test_user('alice@test.com', 'female', 'dating', 1995, 'Istanbul', TRUE, TRUE);
SELECT create_test_user('bob@test.com', 'male', 'dating', 1993, 'Istanbul', TRUE, TRUE);
SELECT create_test_user('carol@test.com', 'female', 'dating', 1997, 'Ankara', TRUE, TRUE);
SELECT create_test_user('dave@test.com', 'male', 'dating', 1990, 'Istanbul', TRUE, TRUE);
SELECT create_test_user('eve@test.com', 'female', 'bff', 1996, 'Izmir', TRUE, TRUE);
SELECT create_test_user('frank@test.com', 'male', 'bff', 1994, 'Istanbul', TRUE, TRUE);

-- Unverified users
SELECT create_test_user('unverified@test.com', 'male', 'dating', 1992, 'Bursa', FALSE, FALSE);
SELECT create_test_user('pending@test.com', 'female', 'dating', 1998, 'Antalya', FALSE, FALSE);
*/

-- ============================================================================
-- CLEANUP FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION cleanup_test_data() RETURNS VOID AS $$
BEGIN
  -- Delete all test data (profiles cascade to other tables)
  DELETE FROM profiles WHERE city IN ('Istanbul', 'Ankara', 'Izmir', 'Bursa', 'Antalya');

  -- Reset sequences if needed
  -- (UUIDs don't need sequence reset)
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SAMPLE QUERIES FOR TESTING
-- ============================================================================

/*
-- Check verification status
SELECT p.user_id, p.gender_claim, v.status as verification_status, e.status as entry_status
FROM profiles p
LEFT JOIN verifications v ON v.user_id = p.user_id
LEFT JOIN entry_status e ON e.user_id = p.user_id;

-- Check if users can like
SELECT user_id, can_user_like(user_id) FROM profiles;

-- Create a test match
INSERT INTO likes (from_user, to_user, mode) VALUES
  ((SELECT user_id FROM profiles WHERE city = 'Istanbul' AND gender_claim = 'female' LIMIT 1),
   (SELECT user_id FROM profiles WHERE city = 'Istanbul' AND gender_claim = 'male' LIMIT 1),
   'dating');

-- Check matches
SELECT * FROM matches;

-- Check match state
SELECT * FROM match_state;
*/
