class ProductQualifier < ApplicationRecord

  belongs_to :qualifier
  belongs_to :product
  belongs_to :certifier

end
