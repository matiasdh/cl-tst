# Sync Pull: Cómo funciona

Sincronización desde la API externa hacia la base local. API → Local.

---

## Resumen

1. **Cron** cada 15 min dispara `PullSyncFetchJob`
2. **FetchJob** llama la API, guarda el payload en Redis, encola `PullSyncProcessJob`
3. **ProcessJob** lee de Redis, parsea y llama `PullSyncService`
4. **PullSyncService** hace `upsert_all` por batches (TodoLists, luego Items)

---

## Arquitectura: dos fases

```
Cron (*/15) → FetchJob → API → Redis (TTL 15 min) → ProcessJob → PullSyncService → DB
```

**¿Por qué dos fases?** Para **reducir llamadas a la API**. Si el ProcessJob falla y Sidekiq reintenta (hasta 5 veces), no volvemos a llamar la API. El payload ya está en Redis; solo reprocesamos. Sin dos fases, cada retry = nueva llamada al API.

| Fase | Job | Si falla |
|------|-----|----------|
| 1 | PullSyncFetchJob | Retry → vuelve a llamar API |
| 2 | PullSyncProcessJob | Retry → lee de Redis, no llama API |

---

## Flujo detallado

### 1. PullSyncFetchJob

- Llama `ExternalTodoApi::TodoLists.new(client).list` (GET /todolists)
- Serializa la respuesta a JSON
- Guarda en `Rails.cache` con key `pull_sync:#{uuid}`, TTL 15 min
- Encola `PullSyncProcessJob.perform_later(payload_key)`

### 2. PullSyncProcessJob

- Recibe `payload_key`
- Lee `Rails.cache.read("pull_sync:#{payload_key}")`
- Si nil (expiró): log + discard
- Parsea con `Parser.parse_todo_lists` → array de structs
- Llama `PullSyncService.new.call(lists)`

### 3. PullSyncService

**Entrada:** array de structs `TodoList` (con items anidados)

**Orden:**

1. **TodoLists en batches** (ej. 50 por batch)
   - `TodoList.upsert_all(rows, unique_by: [:external_source_id, :external_id], update_only: [:name, :synced, :updated_at])`
   - Mapeo: `struct.id` → `external_id`, `struct.source_id` → `external_source_id`

2. **Lookup** `(external_source_id, external_id) => todo_list_id`

3. **Items en batches** (ej. 200 por batch)
   - `Item.upsert_all(rows, unique_by: [:external_source_id, :external_id], update_only: [:description, :completed, :synced, :updated_at])`
   - Cada item incluye `todo_list_id` del lookup

**Errores:** Asumimos que solo falla por red (API, Redis, DB). Si falla, el job completo falla y Sidekiq reintenta. No hay partial failure por batch.

**Tradeoff:** No devolvemos contadores (processed). Código más simple, métricas no necesarias.

---

## Schema relevante

| Columna | Tabla | Uso |
|---------|-------|-----|
| `synced` | todo_lists, items | `true` tras pull o push; `false` si hay cambios locales pendientes |
| `pending_sync_items_count` | todo_lists | Contador de items con `synced: false` |
| `external_id`, `external_source_id` | todo_lists, items | Identificador único para upsert |

---

## Cuándo cambia `synced`

| Evento | synced |
|--------|--------|
| PullSyncService (upsert) | `true` |
| PushSyncJob éxito | `true` |
| Cambios locales | `false` |

---

## Edge cases

Asumimos que **solo falla por conexiones de red** (API, Redis, DB). Sidekiq reintenta hasta 5 veces.

| Caso | Manejo |
|------|--------|
| **Payload expirado** (ProcessJob corre después de 15 min) | `cache.read` → nil → log + return. Próximo cron dispara nuevo FetchJob. |
| **API 5xx / timeout / red** | FetchJob lanza → Sidekiq retry → vuelve a llamar API. |
| **Redis caído** | FetchJob o ProcessJob falla → retry. |
| **DB caído** | ProcessJob falla → retry. No llama API (payload en Redis). |

---

## Archivos

| Archivo | Rol |
|---------|-----|
| `app/jobs/external_todo_api/pull_sync_fetch_job.rb` | Fetch + guardar en Redis |
| `app/jobs/external_todo_api/pull_sync_process_job.rb` | Leer Redis + procesar |
| `app/gateways/external_todo_api/pull_sync_service.rb` | upsert_all por batches |
| `config/sidekiq_cron.yml` | Cron `*/15 * * * *` |
