unless Rails.env.test?
  Rails.application.config.cache_store = :memory_store
end
