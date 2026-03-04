# Crunchloop Interview

This repo contains two projects: the **external API** (`rails-interview-api`) and the **Rails interview** app (`rails-interview`) that syncs with it.

## Setup and run

**Prerequisites:** [just](https://github.com/casey/just) (`brew install just` on macOS), [foreman](https://github.com/ddollar/foreman) for `just start` (`gem install foreman`), Docker (for Redis), and **Ruby** — use the version in `rails-interview-api/.ruby-version` (e.g. via rbenv, rvm, or asdf). **Redis** is used by Sidekiq and by Rails cache in development; start it with `just redis-up`.

### 1. One-time setup

From the repo root:

1. **Install dependencies** in both projects (checks that current Ruby matches `.ruby-version`):
   ```bash
   just setup
   ```

2. **Create and migrate both databases** (drops existing DBs if present, then creates and migrates):
   ```bash
   just db
   ```

3. **(Optional)** Load sample data:
   ```bash
   just seeds
   ```

### 2. Running everything

**Option A — All in one terminal (simplest)**
Starts Redis, then the API (port 3001), the Rails app (port 3000), and Sidekiq:

```bash
just start
```

**Option B — Separate terminals**
Useful if you want to see logs per process or run only some services:

| Command             | Description |
|---------------------|-------------|
| `just setup`        | Install dependencies in both projects (requires Ruby from `.ruby-version`). |
| `just redis-up`     | Start Redis (Docker). Required for Sidekiq. |
| `just redis-down`   | Stop Redis. |
| `just db`           | Drop, create, and migrate both databases. |
| `just api`          | Run the **API** on port **3001**. |
| `just rails`        | Run the **Rails interview** app (web + Tailwind) on port 3000. |
| `just sidekiq`      | Run **Sidekiq** (background jobs). Run in a separate terminal. |
| `just seeds`        | Run **seeds** for the API and the Rails app. |
| `just start`        | Run Redis + API + Rails + Sidekiq in one terminal (requires foreman). |

Typical flow with separate terminals: `just redis-up` → `just api` → `just rails` → `just sidekiq` (and optionally `just seeds` first).

---

## How to test

The idea is to confirm that **changes made in the app on port 3000 show up in the API on port 3001**.

1. **Use the Rails app** at **http://localhost:3000** — create or edit lists and items in the UI.
2. **Check the API** at **http://localhost:3001** — request the same data in JSON (e.g. `GET http://localhost:3001/todolists`). You should see the lists and items you created or updated in the app.

Ensure the API and Sidekiq are running so the app can sync to the API. For full API details and integration tests, see **[https://github.com/crunchloop/interview-tests](https://github.com/crunchloop/interview-tests)**.

### If sync doesn't work

Sync runs in **background jobs** (Sidekiq). All of the following must be running at the same time:

- **Redis** (e.g. `just redis-up`)
- **API** on port 3001 (`just api`)
- **Rails app** on port 3000 (`just rails`)
- **Sidekiq** (`just sidekiq`)

Easiest: use `just start` so all four run together.

- **Rails → API (push):** Creating or editing a list/item in the app enqueues a job; Sidekiq must be running to process it.
- **API → Rails (pull):** A cron job runs every 15 minutes. To run a pull once (fetch from API into Rails), with Sidekiq running do:
  ```bash
  cd rails-interview && bin/rails runner "ExternalTodoApi::PullSyncFetchJob.perform_later"
  ```
  Then wait a few seconds and check the app; the data from `GET http://localhost:3001/todolists` should appear in the Rails app.

If jobs fail (e.g. connection refused to 3001), check the Sidekiq log or Rails log for errors.

---

## Notes to submit

The **notes** to submit are in the Rails interview project:

- **File:** [rails-interview/NOTES.md](rails-interview/NOTES.md)

---

## Full history

If you want to see the complete git history of both projects (`rails-interview-api` and `rails-interview`), they can be provided as separate repositories.
