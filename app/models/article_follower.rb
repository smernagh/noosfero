class ArticleFollower < ActiveRecord::Base

  belongs_to :article, :counter_cache => :followers_count
  belongs_to :person

end
