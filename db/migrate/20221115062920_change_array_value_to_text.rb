class ChangeArrayValueToText < ActiveRecord::Migration[7.0]
  def up
    change_column :users, :recently_played_album_ids, :text
  end

  def down
    change_column :users, :recently_played_album_ids, :integer, array: true, default: []
  end
end
