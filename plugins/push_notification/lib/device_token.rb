class PushNotificationPlugin::DeviceToken < ActiveRecord::Base

  belongs_to :user

  after_save :check_notification_settings

  private

  def check_notification_settings
    if user.notification_settings.nil?
      user.notification_settings=PushNotificationPlugin::NotificationSettings.new
      user.save
    end
  end

end
