class CreateRecurringEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :recurring_events do |t|
      t.datetime "start_time"
      t.datetime "end_time"
      t.string "interval"
      t.string "timezone"
      t.integer "event_count"
      t.jsonb "data"
      t.timestamps
    end
  end
end
