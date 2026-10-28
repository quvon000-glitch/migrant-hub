-- Background refresh jobs: edge functions called by pg_cron through pg_net
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

-- calls an edge function in the background (the anon key is public; the functions only refresh data)
create or replace function public.call_edge(fn text) returns bigint
language sql security definer set search_path = '' as $$
  select net.http_post(
    url := 'https://sepwliohjdveszbvdeuf.supabase.co/functions/v1/' || fn,
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNlcHdsaW9oamR2ZXN6YnZkZXVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMxNDc3NDEsImV4cCI6MjEwODcyMzc0MX0.XiF1f0Vhog_MJqGtrh4E0y-coaTGb8kSpKYeZqX6KcA'),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
$$;
revoke execute on function public.call_edge(text) from public, anon, authenticated;

select cron.schedule('news-refresh', '*/30 * * * *', $$select public.call_edge('news-refresh')$$);
select cron.schedule('fx-refresh', '7 * * * *', $$select public.call_edge('fx-refresh')$$);
select cron.schedule('maintenance', '17 * * * *', $$select public.call_edge('maintenance')$$);
