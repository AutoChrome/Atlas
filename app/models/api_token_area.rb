class ApiTokenArea < ApplicationRecord
  belongs_to :api_token
  belongs_to :area
end
