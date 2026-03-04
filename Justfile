# Crunchloop interview — commands for API, Rails, and seeds
# Requires: just (https://github.com/casey/just). For `start`: foreman (gem install foreman).
# Ruby: use the version in rails-interview-api/.ruby-version (e.g. via rbenv, rvm, or asdf).

default:
    @just --list

# Install dependencies in both projects. Requires Ruby from .ruby-version.
setup:
    #!/usr/bin/env bash
    set -e
    WANT=$(cat rails-interview-api/.ruby-version | tr -d '\n')
    CURRENT=$(ruby -e "puts RUBY_VERSION")
    if [ "$WANT" != "$CURRENT" ]; then
      echo "Ruby version mismatch: need $WANT, got $CURRENT. Use .ruby-version (e.g. rbenv, rvm, or asdf)."
      exit 1
    fi
    (cd rails-interview-api && bin/setup)
    (cd rails-interview && bin/setup)

# Drop (if present), create, and migrate both databases (API and Rails app)
db:
    cd rails-interview-api && (bin/rails db:drop 2>/dev/null || true) && bin/rails db:create db:migrate
    cd rails-interview && (bin/rails db:drop 2>/dev/null || true) && bin/rails db:create db:migrate

# Start Redis (required for rails-interview and Sidekiq). Usage: just redis-up
redis-up:
    cd rails-interview && docker compose up -d

# Stop Redis. Usage: just redis-down
redis-down:
    cd rails-interview && docker compose down

# Run the external API (port 3001)
api:
    cd rails-interview-api && bin/puma

# Run the Rails app (web + Tailwind), port 3000
rails:
    cd rails-interview && bin/dev

# Run Sidekiq for background jobs (run in another terminal)
sidekiq:
    cd rails-interview && bundle exec sidekiq

# Empty all Sidekiq queues and clear retry/scheduled/dead sets (Redis must be up)
sidekiq-clear:
    cd rails-interview && bin/rails runner "require 'sidekiq/api'; Sidekiq::Queue.all.each(&:clear); Sidekiq::RetrySet.new.clear; Sidekiq::ScheduledSet.new.clear; Sidekiq::DeadSet.new.clear; puts 'Sidekiq queues and sets cleared.'"

# Push new todo lists (Rails → API): run create sync for every TodoList without external_id. API must be up.
sync-new-lists:
    cd rails-interview && bin/rails runner "list_ids = TodoList.where(external_id: [nil, '']).pluck(:id); list_ids.each { |id| ExternalTodoApi::PushSyncJob.perform_now('TodoList', id, 'create') }; puts \"Pushed #{list_ids.size} new list(s) to API.\""

# Resync lists that have new items (no external_id): destroy+recreate on API. Run hourly by cron; run now with this.
sync-new-items:
    cd rails-interview && bin/rails runner "ExternalTodoApi::ResyncNewItemsJob.perform_now; puts 'ResyncNewItemsJob done.'"

# Run seeds for the API and the Rails app
seeds:
    cd rails-interview-api && bin/rails db:seed
    cd rails-interview && bin/rails db:seed

# Run Redis, then API, Rails app (web + Tailwind), and Sidekiq in one terminal (requires foreman)
start:
    cd rails-interview && docker compose up -d
    foreman start -f Procfile
