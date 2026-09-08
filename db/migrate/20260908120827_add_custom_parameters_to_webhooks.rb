class AddCustomParametersToWebhooks < ActiveRecord::Migration[8.1]
  def change
    add_column :webhooks, :custom_parameters, :jsonb, default: {}, null: false
  end
end
