-- Country insight aggregate data for AI summary panel.
-- Time-windowed: prefers 72h, falls back to 7d, marks insufficient if < 3 posts.
-- Privacy: returns only aggregate counts, never individual content.

CREATE OR REPLACE FUNCTION public.fetch_country_insight_data(p_country text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_cnt_72h bigint;
  v_cnt_7d  bigint;
  v_win     interval;
  v_win_label text;
  v_dominant  text;
  v_breakdown jsonb;
  v_topics    jsonb;
  v_authors   bigint;
  v_avg_q     float;
  v_eng       jsonb;
BEGIN
  SELECT COUNT(*) INTO v_cnt_72h
  FROM posts
  WHERE country_code = p_country AND is_draft = false AND is_archived = false
    AND primary_mood IS NOT NULL
    AND COALESCE(published_at, created_at) > NOW() - INTERVAL '72 hours';

  SELECT COUNT(*) INTO v_cnt_7d
  FROM posts
  WHERE country_code = p_country AND is_draft = false AND is_archived = false
    AND primary_mood IS NOT NULL
    AND COALESCE(published_at, created_at) > NOW() - INTERVAL '7 days';

  IF v_cnt_72h >= 3 THEN
    v_win := INTERVAL '72 hours';  v_win_label := '72h';
  ELSIF v_cnt_7d >= 3 THEN
    v_win := INTERVAL '7 days';    v_win_label := '7d';
  ELSE
    RETURN jsonb_build_object(
      'country_code', p_country,
      'time_window', 'insufficient',
      'total_posts', COALESCE(v_cnt_7d, 0),
      'data_quality', 'insufficient'
    );
  END IF;

  SELECT COUNT(*), COUNT(DISTINCT user_id), AVG(COALESCE(quality_score, 0.5))
  INTO v_cnt_72h, v_authors, v_avg_q
  FROM posts
  WHERE country_code = p_country AND is_draft = false AND is_archived = false
    AND primary_mood IS NOT NULL
    AND COALESCE(published_at, created_at) > NOW() - v_win;

  SELECT primary_mood INTO v_dominant
  FROM posts
  WHERE country_code = p_country AND is_draft = false AND is_archived = false
    AND primary_mood IS NOT NULL
    AND COALESCE(published_at, created_at) > NOW() - v_win
  GROUP BY primary_mood ORDER BY COUNT(*) DESC LIMIT 1;

  SELECT jsonb_agg(row_to_json(sub)::jsonb ORDER BY sub.count DESC)
  INTO v_breakdown
  FROM (
    SELECT primary_mood AS mood, COUNT(*)::int AS count
    FROM posts
    WHERE country_code = p_country AND is_draft = false AND is_archived = false
      AND primary_mood IS NOT NULL
      AND COALESCE(published_at, created_at) > NOW() - v_win
    GROUP BY primary_mood ORDER BY COUNT(*) DESC LIMIT 6
  ) sub;

  SELECT jsonb_agg(row_to_json(sub)::jsonb ORDER BY sub.count DESC)
  INTO v_topics
  FROM (
    SELECT topic, COUNT(*)::int AS count
    FROM posts,
         LATERAL unnest(COALESCE(topic_labels, ARRAY[]::text[])) AS topic
    WHERE country_code = p_country AND is_draft = false AND is_archived = false
      AND COALESCE(published_at, created_at) > NOW() - v_win
    GROUP BY topic ORDER BY COUNT(*) DESC LIMIT 5
  ) sub;

  SELECT jsonb_build_object(
    'reactions', (SELECT COUNT(*) FROM post_reactions pr JOIN posts p ON pr.post_id = p.id
                  WHERE p.country_code = p_country AND p.is_draft = false AND p.is_archived = false
                    AND COALESCE(p.published_at, p.created_at) > NOW() - v_win),
    'echoes',    (SELECT COUNT(*) FROM post_echoes pe JOIN posts p ON pe.post_id = p.id
                  WHERE p.country_code = p_country AND p.is_draft = false AND p.is_archived = false
                    AND COALESCE(p.published_at, p.created_at) > NOW() - v_win),
    'comments',  (SELECT COUNT(*) FROM post_comments pc JOIN posts p ON pc.post_id = p.id
                  WHERE p.country_code = p_country AND p.is_draft = false AND p.is_archived = false
                    AND COALESCE(p.published_at, p.created_at) > NOW() - v_win)
  ) INTO v_eng;

  RETURN jsonb_build_object(
    'country_code',   p_country,
    'time_window',    v_win_label,
    'total_posts',    v_cnt_72h,
    'unique_authors', v_authors,
    'avg_quality',    ROUND(v_avg_q::numeric, 2),
    'dominant_mood',  v_dominant,
    'mood_breakdown', COALESCE(v_breakdown, '[]'::jsonb),
    'top_topics',     COALESCE(v_topics, '[]'::jsonb),
    'engagement',     v_eng,
    'data_quality',   CASE
      WHEN v_cnt_72h >= 10 THEN 'good'
      WHEN v_cnt_72h >= 5  THEN 'moderate'
      ELSE 'limited'
    END
  );
END;
$$;
