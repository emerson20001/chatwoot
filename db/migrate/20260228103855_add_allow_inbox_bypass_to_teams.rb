class AddAllowInboxBypassToTeams < ActiveRecord::Migration[7.0]
  def change
    add_column :teams, :allow_inbox_bypass, :boolean, default: false, null: false
  end
end
