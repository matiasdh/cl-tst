class TodoList < ApplicationRecord
  has_many :items, dependent: :destroy

  validates :name, presence: true
  validates :external_id, uniqueness: { scope: :external_source_id, allow_blank: true }

  scope :with_associations, -> { includes(:items) }
end
