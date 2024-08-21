class Track < ApplicationRecord
  belongs_to :group

  enum kind: { public: 'public', private: 'private' }
end
