import Config

# Load runtime configuration for Supabase
config :mindre_cash, :supabase,
  url: System.get_env("SUPABASE_URL"),
  key: System.get_env("SUPABASE_KEY")

# Print a warning if the Supabase configuration is missing
if is_nil(System.get_env("SUPABASE_URL")) do
  IO.warn("SUPABASE_URL environment variable is not set")
end

if is_nil(System.get_env("SUPABASE_KEY")) do
  IO.warn("SUPABASE_KEY environment variable is not set")
end
