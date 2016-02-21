class EnvironmentNotificationsUser < ApplicationRecord
  self.table_name = "environment_notifications_users"

  belongs_to :user
  belongs_to :environment_notification, class_name: 'EnvironmentNotificationPlugin::EnvironmentNotification'

  validates_uniqueness_of :user_id, :scope => :environment_notification_id
end
