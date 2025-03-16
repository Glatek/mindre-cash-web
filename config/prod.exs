import Config

# Add your dev-specific configuration here

# Import runtime configuration
if File.exists?("config/runtime.exs") do
  import_config "runtime.exs"
end
