class AddUserToJobOpening < ActiveRecord::Migration[8.1]
  def change
    add_reference :job_openings, :user, null: true, foreign_key: true
  end
end
