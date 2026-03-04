require 'sidekiq-cron'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1") }
  config.on(:startup) do
    Sidekiq::Cron::Job.load_from_hash(YAML.safe_load_file(Rails.root.join('config', 'sidekiq_cron.yml')))
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1") }
end
