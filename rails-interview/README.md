# rails-interview / TodoApi

[![Open in Coder](https://dev.crunchloop.io/open-in-coder.svg)](https://dev.crunchloop.io/templates/fly-containers/workspace?param.Git%20Repository=git@github.com:crunchloop/rails-interview.git)

This is a simple Todo List API built in Ruby on Rails 7. This project is currently being used for Ruby full-stack candidates.

## Build

To build the application:

`bin/setup`

## Run the API

Before running the API, ensure you start the required background services (like Redis) using Docker Compose:

`docker compose up -d`

When you are done, you can stop the services with:

`docker compose down`

To run the TodoApi in your local environment:

`bin/puma`

For background jobs to run, start Sidekiq in a separate terminal:

`bundle exec sidekiq`

## Bulk Update (Items)

The bulk update endpoint marks multiple items as completed asynchronously to avoid blocking the web server on long requests.

**Endpoint:** `PATCH /api/todolists/:todo_list_id/todos/bulk_update`

**Parameters:**
- `all` (boolean): When `true`, marks all items in the todo list as completed.
- `item_ids` (array): When provided, marks only the specified item IDs as completed.

**Response:** `202 Accepted` with JSON body:
```json
{ "task_id": "e838f81c-ebee-4b8b-aad3-53ffcba9676f" }
```

**Flow:**
1. The request returns immediately with a unique `task_id`.
2. The actual update runs in a Sidekiq background job.
3. When the job completes, it broadcasts `{ "status": "completed" }` via ActionCable to the stream `bulk_update_<task_id>`.
4. Clients can subscribe to the channel to receive the completion notification in real time (see below).

**Subscribing to completion notifications (ActionCable):**

API clients that need real-time notification when a bulk update finishes should:

1. Connect to the ActionCable WebSocket at `ws://<host>/cable` (or `wss://` in production).
2. Subscribe to channel `BulkUpdateChannel` with the `task_id` from the 202 response.
3. When the job completes, the client receives `{ "status": "completed" }` on that subscription.

Example (JavaScript with `@rails/actioncable`):

```javascript
import { createConsumer } from "@rails/actioncable"

const consumer = createConsumer()
const subscription = consumer.subscriptions.create(
  { channel: "BulkUpdateChannel", task_id: taskId },
  {
    received(data) {
      if (data.status === "completed") {
        // Refresh items, update UI, etc.
      }
    }
  }
)
// Call subscription.unsubscribe() when done
```

**Verified examples (curl):**

Ensure the API and Sidekiq are running. Create test data: `bin/rails db:seed` for todo lists, then `POST /api/todolists/:id/todos` to add items. Replace `99` with your todo list ID; use your item IDs in `item_ids` when updating specific items.

*Update all items:*
```bash
$ curl -s -X PATCH "http://localhost:3000/api/todolists/99/todos/bulk_update" \
  -H "Content-Type: application/json" \
  -d '{"all": true}'
{"task_id":"e838f81c-ebee-4b8b-aad3-53ffcba9676f"}
```

*Update specific items (IDs 4 and 6):*
```bash
$ curl -s -X PATCH "http://localhost:3000/api/todolists/99/todos/bulk_update" \
  -H "Content-Type: application/json" \
  -d '{"item_ids": [4, 6]}'
{"task_id":"a2013a30-c4c6-4599-ad9b-1ffd441974ee"}
```

*Before/after (GET index):*
```bash
$ curl -s "http://localhost:3000/api/todolists/99/todos"
[{"id":4,"description":"Item A","completed":false},{"id":5,"description":"Item B","completed":false},{"id":6,"description":"Item C","completed":false}]

# After bulk_update with item_ids [4, 6] and Sidekiq processing the job:
[{"id":4,"description":"Item A","completed":true},{"id":5,"description":"Item B","completed":false},{"id":6,"description":"Item C","completed":true}]
```

## External Todo API Client

HTTP client for the external Todo API. Configure via `.env` (copy from `.env.sample`) or `config/external_todo_api.yml`.

**Usage:**

```ruby
# Todo lists (client optional, defaults to Client.new)
todo_lists = ExternalTodoApi::TodoLists.new
todo_lists.list
todo_lists.create(payload)  # payload: CreateTodoList struct
todo_lists.update(id: 1, name: "New name")
todo_lists.delete(id: 1)

# Items (within a list)
todo_lists.items.update(todo_list_id: 1, todo_item_id: 10, completed: true)
todo_lists.items.delete(todo_list_id: 1, todo_item_id: 10)

# With custom client
client = ExternalTodoApi::Client.new
todo_lists = ExternalTodoApi::TodoLists.new(client)
```

**Config (optional, via `.env` or `config/external_todo_api.yml`):**
- `EXTERNAL_TODO_API_URL` — Base URL (default: `http://localhost:3001`)
- `EXTERNAL_TODO_API_SOURCE_ID` — Source identifier (default: `rails-interview`)
- `EXTERNAL_TODO_API_TIMEOUT` — Request timeout in seconds (default: `10`)
- `EXTERNAL_TODO_API_RETRIES` — Retry attempts on failure (default: `3`)

## Documentation

- **[Sync Pull (API → Local)](docs/SYNC_PULL.md)** — How the pull sync works: two-phase jobs (fetch → process), batches, `synced` flag, and partial failure handling. Tradeoff: simpler code, no metrics.

## Test

To run tests:

`bin/rspec`

Check integration tests at: (https://github.com/crunchloop/interview-tests)

## Contact

- Santiago Doldán (sdoldan@crunchloop.io)

## About Crunchloop

![crunchloop](https://s3.amazonaws.com/crunchloop.io/logo-blue.png)

We strongly believe in giving back :rocket:. Let's work together [`Get in touch`](https://crunchloop.io/#contact).
