class FileAccessLog < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :report, optional: true

  enum :action, {
    download: "download"
  }, default: "download"

  validates :file_path, presence: true
end

