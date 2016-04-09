class PushNotificationPlugin::NotificationSubscription < ActiveRecord::Base

  belongs_to :environment

  validates :notification, :uniqueness => true
  serialize :subscribers

end

