import Config

# Add any global configuration options here.

# Finally, import env-specific configuration
# (to allow it to override the global defaults above).
import_config "#{config_env()}.exs"
