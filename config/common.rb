require 'active_record'
require 'date'

KANABELL_CODE = '0010'.freeze
YUYUTEI_CODE = '0020'.freeze
CARDRUSH_CODE = '0030'.freeze

dbname = 'ygo_crawler'

# idcfが含まれていたら本番扱い。本番ではログは出さない
if `hostname -f`.include?('idcf') # 本番環境
  host = '' # 本番dbに接続
  user = dbname
  pass = "#{user}!"
else # 開発環境
  host = 'localhost'
user = 'root'
  pass = ''
  ActiveRecord::Base.logger = Logger.new(STDERR)
end

ActiveRecord::Base.establish_connection(
  adapter: "mysql2",
  host: host,
  username: user,
  password: pass,
  database: dbname,
)

ActiveRecord.default_timezone = :local
Time.zone_default = Time.find_zone! 'Tokyo'

class Source < ActiveRecord::Base
  has_many :cards
  scope :waiting, -> { where(status: 0..1) }
end

class CardMaster < ActiveRecord::Base
  has_many :cards
  scope :waiting, -> { where(status: 0..1) }
end

class Card < ActiveRecord::Base
  belongs_to :card_master
  belongs_to :source
  has_many :pages
end

class Page < ActiveRecord::Base
  belongs_to :card
  has_many :prices
end

class Price < ActiveRecord::Base
  belongs_to :page
end

class Site < ActiveRecord::Base; end

class Log < ActiveRecord::Base
  self.primary_key = :id

  def self.create_log_record(**log)
    create(
      program_name: caller.first,
      crawler_category: log[:category],
      error_class: log[:error].class,
      message: log[:error].message
    )
  end
end
