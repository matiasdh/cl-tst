unless Rails.env.test?
  redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
  Rails.application.config.cache_store = :redis_cache_store, {
    url: redis_url,
    expires_in: 90.minutes
  }
end
