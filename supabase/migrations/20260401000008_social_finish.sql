-- =============================================================================
-- SOCIAL FINISH: Final notification before purge, +3 mode companion limit
-- =============================================================================

-- ═══════════════════════════════════════════════════════════════════
-- 1. CRON: Send farewell notification at +4h, BEFORE purge at +4h10m
-- ═══════════════════════════════════════════════════════════════════

DO $$ BEGIN PERFORM cron.unschedule('send-farewell-notifications'); EXCEPTION WHEN OTHERS THEN NULL; END $$;
SELECT cron.schedule('send-farewell-notifications', '*/15 * * * *', $$
  INSERT INTO public.notifications (user_id, type, title, body, data)
  SELECT ep.user_id, 'event_farewell',
    'Event ended',
    'It was a good one. This room will disappear in 10 minutes.',
    jsonb_build_object('event_id', e.id)
  FROM public.events e
  JOIN public.event_participants ep ON ep.event_id = e.id AND ep.attendance_status != 'out'
  WHERE e.status = 'locked'
    AND e.event_date + INTERVAL '4 hours' < NOW()
    AND e.event_date + INTERVAL '4 hours 10 minutes' > NOW()
    AND NOT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE n.user_id = ep.user_id AND n.type = 'event_farewell'
        AND (n.data->>'event_id')::text = e.id::text
    );
$$);
