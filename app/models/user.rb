class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :api_tokens, dependent: :destroy
  has_many :pages, dependent: :nullify
  has_many :announcements, dependent: :nullify

  audited except: [ :password_digest ]

  enum :role, { member: 0, admin: 1, guest: 2 }, default: :member

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: { case_sensitive: false },
                             format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, allow_nil: true, length: { minimum: 8 }
end
