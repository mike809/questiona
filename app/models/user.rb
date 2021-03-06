# == Schema Information
#
# Table name: users
#
#  id              :integer          not null, primary key
#  username        :string(255)
#  first_name      :string(255)
#  last_name       :string(255)
#  bio             :string(255)
#  email           :string(255)
#  password_digest :string(255)
#  session_token   :string(255)
#  password_token  :string(255)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#


class User < ActiveRecord::Base
  
  VALID_EMAIL_REGEX = Regexp.new(/\A[\w\d\.-]+@(?:\w+\.)+[\w]{2,}\Z/i)
  VALID_USERNAME_REGEX = Regexp.new(/\A\w+[\d\w\-\_]*\Z/i)

  attr_accessible :username, :password_digest, 
                  :password, :first_name,
                  :last_name, :email, :bio

  attr_accessor :password

  validates :email, :format => { :with => VALID_EMAIL_REGEX }
  validates :username, :format => { :with => VALID_USERNAME_REGEX }

  validates :email, :username,
            :presence => true,
            :uniqueness => { :case_sensitive => false } 
  
  validates :password_digest, :presence => true

  validates :password,
            :presence => true,
            :length => { :minimum => 6 },
            :on => :create

  before_validation :ensure_session_token!

  has_many :i_followed, :class_name => "Follow" , :foreign_key => :follower_id
  has_many :followed_me, :class_name => "Follow", :foreign_key => :followee_id

  has_many :followers, :through => :followed_me, :source => :follower

  has_many :authored_questions,
           :class_name => "Question",
           :foreign_key => :author_id

  has_many :answered_questions,
           :class_name  => "Answer",
           :foreign_key => :author_id

  has_many :upvoted_answers, :class_name => "Upvote"

  def people_followed
    User.find_by_sql(<<-SQL 
      SELECT 
        users.* 
      FROM 
        users
      JOIN 
        follows 
        ON 
        users.id = follows.followee_id 
      WHERE 
        follows.follower_id = #{self.id}
          AND 
        follows.type_followee = 'user'
      SQL
    )
  end

  def self.find_by_credentials(login, password)              
  	user = User.where(":login = lower(username) OR :login = lower(email)", :login => login.downcase).first;
  	return nil unless user
  	is_password?(user.password_digest, password) ? user : nil
  end

  def self.is_password?(password_digest, plain_text)
    BCrypt::Password.new(password_digest) == plain_text
  end

  def password=(plain_text)
    @password = plain_text
  	self.password_digest = BCrypt::Password.create(plain_text)
  end

  def reset_session_token!
  	self.session_token = SecureRandom.urlsafe_base64
  end

  def ensure_session_token!
    unless self.session_token
      self.reset_session_token!
    end
  end

  def self.search(keywords)
    User.where("lower(username) like ? OR lower(first_name) like ? OR \
              lower(last_name) like ?", *(["%#{keywords.downcase}%"] * 3)) || []
  end

  def full_name
    "#{self.first_name} #{self.last_name}"
  end

  def to_param
    self.username
  end

  def activities
    Activity.where("(subject_id = #{self.id} AND subject_type = 'User') 
                 OR (target_id  = #{self.id} AND target_type  = 'User')")
  end

  def notifications
    Notification.where("owner_id = #{self.id} AND owner_type = 'User'")
  end

  def feed
    activity = activities
    
    self.people_followed.each do |person|
      activity += person.activities
    end

    activity.uniq
  end

  def name
    full_name
  end

end
