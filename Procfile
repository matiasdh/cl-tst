# Run from repo root with: foreman start -f Procfile (or just start)
api: cd rails-interview-api && PORT=3001 bin/puma
web: cd rails-interview && PORT=3000 bin/rails server
css: cd rails-interview && bin/rails tailwindcss:watch
sidekiq: cd rails-interview && bundle exec sidekiq
