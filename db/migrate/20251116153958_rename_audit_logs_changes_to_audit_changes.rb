class RenameAuditLogsChangesToAuditChanges < ActiveRecord::Migration[7.1]
  def change
    rename_column :audit_logs, :changes, :audit_changes
  end
end
