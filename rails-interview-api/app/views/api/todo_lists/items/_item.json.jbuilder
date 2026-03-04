json.id item.id.to_s
json.source_id item.external_source_id if item.external_source_id.present?
json.description item.description
json.completed item.completed
json.created_at item.created_at&.iso8601
json.updated_at item.updated_at&.iso8601
