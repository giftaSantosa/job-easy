class User < ApplicationRecord
  has_many :tasks, dependent: :destroy
  has_many :job_applications, dependent: :destroy
  has_many :resumes, through: :job_applications
  has_many :job_openings, dependent: :destroy
  # check this later
  has_one :job_opening, through: :job_applications
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  def default_resume
    resumes.find_by(is_default: true)
  end

  def username
    (email.to_s.split("@", 2).first.presence || "User").capitalize
  end
end
