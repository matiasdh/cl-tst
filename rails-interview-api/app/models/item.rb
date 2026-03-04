class Item < ApplicationRecord
  belongs_to :todo_list

  scope :syncable, -> { where.not(external_id: [nil, ""]) }

  validates :description, presence: true
  validates :completed, inclusion: { in: [ true, false ] }
  validates :external_id, uniqueness: { scope: :external_source_id, allow_blank: true }
end
