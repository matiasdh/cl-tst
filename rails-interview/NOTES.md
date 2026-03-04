# Design Notes

Design decisions, trade-offs, and assumptions for the Todo API and sync layer.

---

## High-Level Overview

- **Domain model**: `TodoList` and `Item` have `external_id`, `external_source_id` and `synced` fields to map 1:1 to the entities of the External Todo API defined in the [External Todo API spec](https://raw.githubusercontent.com/crunchloop/challenge-senior-engineer/refs/heads/main/docs/external-api.yaml). `TodoList` also exposes `pending_sync_items_count` to track how many local items are pending push.
- **Service objects**: `ApplicationService` provides a `.call(**args)` helper. `Todos::*` services encapsulate persistence and sync logic; controllers delegate to them. No ActiveRecord callbacks are used for synchronization.
- **Gateways**: The `ExternalTodoApi` namespace implements the HTTP client (`Client`), parser (`Parser`), structs (`TodoList`, `TodoItem`, `CreateTodoList`, `CreateTodoItem`) and high-level classes `TodoLists` and `TodoLists::Items` that wrap the external API endpoints.
- **Push sync (Local → External)**: Domain services and some jobs enqueue `ExternalTodoApi::PushSyncJob` when lists or items change. The job delegates to `PushSyncService`, which uses `PushSync::TodoListHandler` and `PushSync::ItemHandler` to translate create/update/delete operations into concrete HTTP calls.
- **Pull sync (External → Local)**: A two-phase flow (`PullSyncFetchJob` + `PullSyncProcessJob`) fetches all lists and items with `GET /todolists`, stores the raw payload in cache and then `PullSyncService` performs batched upserts into the local database, respecting unsynced local changes.

---

## Key Design Decisions

### 1. Service objects instead of callbacks

Services like `Todos::CreateTodoListService`, `Todos::UpdateTodoListService`, `Todos::DestroyTodoListService`, `Todos::UpdateItemService` and `Todos::DestroyItemService` encapsulate business logic and explicitly enqueue push-sync jobs when needed. ActiveRecord callbacks are not used for sync.

**Rationale:** Keeps side effects to external systems out of model callbacks, makes controllers thin and keeps sync rules explicit and testable.

### 2. PushSyncable for DRY push logic

The `PushSyncable` concern centralizes `enqueue_push_sync` and `enqueue_push_sync_delete`, reused by several `Todos::*` services. It only enqueues jobs when a record has an `external_id` and, for deletes, sends the minimal attributes (`external_id`, `external_source_id`, `todo_list_id`) needed to reconstruct a `DeletedRecord`.

**Rationale:** Avoids duplicating enqueue logic, keeps the decision of “when to push” in a single place, and allows evolving the push protocol without touching all services.

### 3. DeletedRecord for phantom deletes

When deleting records that must also be deleted remotely, we pass `record_id: nil` and `deleted_attrs` to `PushSyncJob`. `PushSync::DeletedRecord.build` creates an immutable object with `external_id`, `external_source_id` and optionally `todo_list`, loaded from `todo_list_id` for items.

**Rationale:** The local record is gone when the job runs. `DeletedRecord` preserves the minimal context required to call `DELETE` on the external API and, for items, to decrement `pending_sync_items_count` on the associated list.

### 4. pending_sync_items_count as incremental counter

`TodoList` maintains `pending_sync_items_count` as a counter of items pending push. It is updated with `increment!`/`decrement!`:

- `Todos::UpdateItemService` and `Todos::DestroyItemService` increment the counter when they mark an item as pending sync.
- `PushSync::ItemHandler` decrements the counter after a successful remote update/delete.
- `ItemsBulkUpdateJob` increments the counter in bulk (`+ syncable_item_ids.size`) for mass-completion operations.

**Rationale:** Constant-time updates per operation instead of recomputing with full-table queries. Drift is possible if a bug skips an increment/decrement, but acceptable at the current scale and can be corrected with a reconciliation task.

### 5. Item.syncable scope

`Item.syncable` is defined as `where.not(external_id: [nil, ""])` and is reused in `ItemsBulkUpdateJob` to decide which items should enqueue push-sync jobs.

**Rationale:** Encodes the “syncable item” concept in a reusable scope and avoids ad-hoc `external_id` checks across the codebase.

### 6. CreateTodoListService always enqueues push

`CreateTodoListService` enqueues `PushSyncJob` with action `create` for every new `TodoList`, even though the local `external_id` is initially nil.

**Rationale:** The external API assigns the remote `id`. `PushSync::TodoListHandler` issues `POST /todolists` and persists `external_id` and `external_source_id` from the response into the list and its items, marking them as `synced: true`.

### 7. CreateItemService creates local-only items

`CreateItemService` does not enqueue push for new items.

**Rationale:** The external API does not expose an endpoint to create items in existing lists (`POST /todolists/{todolistId}/todoitems`), so new items are intentionally local-only and remain without `external_id`, which keeps them out of the sync layer.

### 8. ResyncNewItemsJob: Destroy & Recreate for new items

A periodic Sidekiq Cron job (`ResyncNewItemsJob`, every hour) finds todo lists that have been synced remotely (`external_id` present) but contain items without `external_id` (i.e., items created locally after the initial push). For each such list, the job:

1. **Deletes** the list on the external API (`DELETE /todolists/:external_id`).
2. **Recreates** it (`POST /todolists`) with all current items.
3. **Persists** new `external_id` and `external_source_id` on the list and every item.
4. **Marks** everything as `synced: true` and resets `pending_sync_items_count` to `0`.

**Rationale:** The external API has no `POST /todolists/{todolistId}/todoitems` endpoint. The only available path to sync new items is to destroy the entire list remotely and recreate it with the full set of items. This is a pragmatic workaround given the API limitation.

**Trade-offs:**

| Benefit | Cost |
|---|---|
| New items eventually reach the external API | Temporary data loss window: between delete and recreate, the list doesn't exist remotely |
| No changes needed on the external API | All remote item IDs change on every resync (downstream consumers tracking item IDs would break) |
| Hourly cadence limits API load | Up to 1 hour of delay before new items are visible externally |
| Simple implementation reusing existing handlers | `N+1` API calls (1 delete + 1 create per affected list); acceptable at moderate scale |

**Item matching after recreate:** When the list is recreated remotely, the external API assigns entirely new IDs to the list and all its items. To update local records with the new `external_id` values, we need to match each local item to its corresponding remote item in the response. The external API does not support passing a client-side reference ID — `source_id` identifies the *source system*, not individual records. We use **positional matching (zip)** with `record.items.order(:id)` to ensure a deterministic local order. This assumes the API returns items in the same order they were sent. Matching by `description` was considered but rejected because descriptions are not unique — a list can have multiple items with the same description, which would produce ambiguous matches.

**Synced guard in `ItemHandler#update`:** After a resync marks items as `synced: true`, subsequent `PushSyncJob`s enqueued before the resync (e.g., from a bulk update) would make redundant API calls. The `ItemHandler` now checks `record.synced?` and skips the update if already synced, preventing duplicate work.

**Index considerations:** The resync query joins `todo_lists` and `items` filtering on `external_id`. The existing composite indexes `(external_source_id, external_id)` on both tables are not effective for this query since `external_id` is the second column. However, **no additional indexes are added** because the job runs hourly (not in a hot path) and the expected data volume is moderate. If the tables grow significantly, single-column indexes on `items.external_id` and `todo_lists.external_id` could be added.

---

## Resilience and Error Handling

### HTTP client and retries

- `ExternalTodoApi::Client` uses Faraday configured with:
  - `base_url`, `timeout` and `retries` from `Rails.application.config.external_todo_api`.
  - The `faraday/retry` middleware to retry idempotent methods (`GET`, `DELETE`, `PATCH`, `PUT`, `HEAD`) on common transient statuses (`429`, `500`, `502`, `503`, `504`).
- `handle_response!` turns non-successful responses into rich exceptions:
  - `NotFoundError` for 404.
  - `ServerError` for 5xx.
  - `ClientError` for the remaining 4xx.
  - Each error captures `status`, a truncated `body` and the `url`, which are ideal for logging and debugging.

### Jobs with retry_on and discard_on

- `ExternalTodoApi::PushSyncJob`, `PullSyncFetchJob` and `PullSyncProcessJob` are configured with:
  - `retry_on StandardError, wait: :polynomially_longer, attempts: 5` to handle transient failures (network, external API, DB).
  - `discard_on ActiveJob::DeserializationError` and `discard_on ActiveRecord::RecordNotFound` in `PushSyncJob`, avoiding useless retries when the record no longer exists or arguments cannot be deserialized.

### Sync logging

- **Push sync**:
  - `ExternalTodoApi::PushSyncJob` logs an `info` at the start of each run with record type, id (including the deleted case, rendered as `nil(deleted)`) and action (`create`, `update`, `delete`).
  - After a successful push it logs another `info` with the same context, marking completion.
  - On any `StandardError` it logs an `error` with `error=#{e.class}: #{e.message}` and re-raises, so `retry_on` can apply. This gives a full audit trail of attempts, successes and failures.
- **Pull sync**:
  - `PullSyncFetchJob` emits a `warn` when the cache write fails, and in that case it does not enqueue the process job.
  - `PullSyncProcessJob` emits a `warn` when the payload is missing or expired in cache at execution time.

Together, retries plus structured logging make the sync layer resilient and diagnosable in production.

---

## Edge Cases

- **External vs local conflicts (`synced` as local lock)**:
  - `PullSyncService` performs batched upserts with `on_duplicate_key_update` conditioned on `synced = 1`. If a local record has `synced = false` (pending changes), external data will not overwrite it.
- **Unknown or orphan items**:
  - `PullSyncService` first builds a lookup map of local `TodoList` records by `(external_source_id, external_id)`. Items whose parent list cannot be found locally are skipped, preventing a partially-failed batch from breaking the whole sync.
- **Local-only items**:
  - Items without `external_id` never enter the sync pipeline (they do not match the `syncable` scope) and there is no external endpoint to create them in-place. They are intentionally local.
- **Deferred deletes**:
  - Deletes are handled via `DeletedRecord` built from `deleted_attrs`. Even if the local row is gone, the job retains enough context to call `DELETE` on the external API and, for items, decrement `pending_sync_items_count` on the parent list.

---

## Areas for Improvement

### Desired changes in the External API for better integration

- **Filter by update date**: Support query parameters (e.g. `updated_after`, `updated_before`) on `GET /todolists` (and on items) so clients can pull only lists or items modified since a given time, reducing payload size and making incremental sync simpler.
- **Create items in an existing list**: Expose `POST /todolists/{todolistId}/todoitems` so new items can be created directly under a list instead of relying on the destroy-and-recreate resync workaround (see §8 above).
- **Webhooks for changes**: When a todo list or item is created, updated, or deleted on the External API, send a webhook notification to a configurable URL (e.g. with event type, resource id, and timestamp). That would allow this app to react to external changes in real time instead of (or in addition to) polling.
- **Pagination**: Support cursor- or page-based pagination on `GET /todolists` (and on items per list) so clients can fetch in chunks instead of a single large response, improving reliability and memory use at scale.
- **Client reference id on create**: Echo back an optional `client_reference_id` in create responses so clients can match local records to remote ones without relying on response order (see §8 item matching).

---

- **Batch endpoints in the External API**:
  - Push currently issues one HTTP call per affected record (a limitation of the API). Batch endpoints for `PATCH/DELETE` of multiple items or lists would reduce network overhead and improve latency for large operations.
- **Endpoint to create items in existing lists (recommended API change)**:
  - A `POST /todolists/{todolistId}/todoitems` endpoint would **eliminate the need for the destroy-and-recreate resync** entirely. `CreateItemService` could simply push the new item to the external API and receive an `external_id` in the response, just like `CreateTodoListService` does for lists.
  - This would remove: the hourly resync job, the temporary remote data loss window, the remote ID churn, and the `synced?` guard complexity.
  - **This is the single most impactful change the external API could make** to simplify the sync architecture.
- **`client_reference_id` field in create payloads (recommended API change)**:
  - Adding an optional `client_reference_id` field to `CreateTodoItemBody` (and `CreateTodoListBody`) that the API echoes back in the response would allow clients to reliably match local records to their remote counterparts without relying on positional ordering. This would make the destroy-and-recreate resync robust against any API response ordering changes.
- **Sync metrics and observability**:
  - Adding counters (for example via Prometheus) per operation type, retries and errors by endpoint would make it easier to detect external API degradation and configuration issues.
- **Reconciliation of `pending_sync_items_count`**:
  - A rake task that recomputes the counter from the actual state of `Item` could fix drift introduced by bugs or manual DB operations.
- **Operational tooling**:
  - Admin endpoints or maintenance tasks to re-run a full pull or force a re-sync of a specific list would simplify support for exceptional cases.

---

## Real-time completed items (UI)

The Todo List show view updates the list of items in real time when items are marked completed, so that all clients viewing the same list see changes without reloading. Counts (completed/pending/total) are not shown on the show view and are not updated in real time.

### Escenario “un ítem” (single item complete)

When a user marks one item as completed (button “Complete” on a row):

- The client that clicked receives the usual Turbo Stream response and the items frame is updated (that row shows as completed).
- The server also broadcasts a Turbo Stream `replace` for that item to the todo list’s stream (`Turbo::StreamsChannel.broadcast_replace_to(todo_list, ...)`). Every browser that has the list open and is subscribed via `turbo_stream_from todo_list` receives this broadcast. If the completed item is on the current page, its row updates to the completed state; if not, only the summary (if present) would change — in this app the summary is removed, so only the item row updates when it is in view.

### Escenario “bulk” (complete selected / complete all)

When the user completes multiple items ( “Complete selected” or “Complete all”):

- The request is handled synchronously and the job `ItemsBulkUpdateJob` runs. It marks the items completed and then broadcasts a message `{ action: "refresh_items" }` on the Action Cable channel `todo_list_<id>` (no Turbo Stream replace of the whole frame, to avoid forcing page 1 for everyone).
- Each client that has the list open is subscribed to `TodoListChannel` for that list (via a Stimulus controller). On receiving `refresh_items`, the client refreshes only the items frame: it sets the frame’s `src` to the current page URL (including `?page=...`). Turbo fetches that URL and replaces the frame with the matching fragment from the response, so each user sees their current page updated with the new completed state.

### Escalar (WebSockets)

The implementation uses Rails’ built-in Action Cable (with Redis adapter in development/production). For higher scale (many concurrent WebSocket connections), [AnyCable](https://anycable.io/) can be used as a drop-in replacement: it is compatible with the Action Cable API, so the same channels and broadcasts work; you run an AnyCable server and point the client to it instead of the default `/cable` endpoint.

---

## Assumptions

- **External API**:
  - Follows the OpenAPI contract in the [External Todo API spec](https://raw.githubusercontent.com/crunchloop/challenge-senior-engineer/refs/heads/main/docs/external-api.yaml).
  - Does not offer batch endpoints or `POST /todolists/{todolistId}/todoitems` for creating items in existing lists.
- **Scale and tenancy**:
  - Single-tenant environment with moderate numbers of lists and items. No sharding or advanced partitioning is required.
- **Expected failures**:
  - Most failures are infrastructural (network, external API, Redis, DB). `retry_on` in jobs and `faraday/retry` are sufficient to handle transient issues.
- **Consistency model**:
  - Local changes marked with `synced = false` take precedence over external data. The sync layer does not attempt complex multi-master conflict resolution.
- **UI**:
  - The web UI is intentionally minimal and does not include a dedicated sync dashboard yet; operators rely primarily on logs and, in the future, metrics.

---

## Running the Sync Locally

- **Configuring the External API client**:
  - Define `Rails.application.config.external_todo_api` with at least:
    - `base_url`: base URL of the External Todo API (for example `http://localhost:3001`).
    - `source_id`: identifier for this local system, sent when creating remote lists/items.
    - `timeout`: HTTP request timeout (seconds).
    - `retries`: maximum number of retries for idempotent requests.
- **Running Pull Sync manually**:
  - From a Rails console, enqueue `ExternalTodoApi::PullSyncFetchJob.perform_later`. This will perform a single `GET /todolists`, store the payload in cache and enqueue `PullSyncProcessJob`, which calls `PullSyncService` to upsert lists and items in batches.
- **Running Push Sync manually**:
  - Any operation that goes through the `Todos::*` services (creating/updating/deleting syncable lists or items) will automatically enqueue `ExternalTodoApi::PushSyncJob`.
  - Alternatively, you can enqueue jobs directly, e.g. `ExternalTodoApi::PushSyncJob.perform_later("TodoList", some_id, "update")`.
- **Processing job queues**:
  - Run Sidekiq (or the configured job backend) ensuring that the `external_sync` queue is processed in addition to the default queues.
