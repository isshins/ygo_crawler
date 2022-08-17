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

  def self.create_new?(sources)
    new_sources = sources.reject{|source| Source.exists?(pack_id: source[:pack_id])}
    if new_sources.empty?
      false
    else
      new_sources.each{|source| Source.create(source)}
      true
    end
  end
end

class CardMaster < ActiveRecord::Base
  has_many :cards
  scope :waiting, -> { where(status: 0..1) }
  scope :crawled, -> { where(status: 2).or(where(status: 4)) }
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

class Site < ActiveRecord::Base

  def self.crawled(site_code)
    {find_by(site_code: site_code).en_name.to_sym => true}
  end
end

class Log < ActiveRecord::Base
  self.primary_key = :id

  def self.create_log_record(**log)
    create(
      program_name: caller.first,
      category: log[:category],
      paramater_id: log[:paramater_id],
      event_name: log[:event_name],
      message: log[:message]
    )
  end
end
