# frozen_string_literal: true

class Album < ApplicationRecord
  DEFAULT_NAME = 'Unknown Album'

  validates :name, presence: true
  validates :name, uniqueness: { scope: :artist }

  has_many :songs, dependent: :destroy
  belongs_to :artist

  has_one_attached :image

  def has_image?
    image.attached?
  end
end
