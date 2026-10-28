/// Supabase project of Migrant Hub. The anon key is public by design: every table is protected by RLS.
/// Override at build time with --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://sepwliohjdveszbvdeuf.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNlcHdsaW9oamR2ZXN6YnZkZXVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMxNDc3NDEsImV4cCI6MjEwODcyMzc0MX0.XiF1f0Vhog_MJqGtrh4E0y-coaTGb8kSpKYeZqX6KcA',
  );
}
