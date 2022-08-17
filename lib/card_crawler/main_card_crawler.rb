require_relative '../../config/common'
require_relative './source_crawler'
require_relative './card_master_crawler'
require_relative './cards_crawler'
Dir[File.expand_path("../page_crawler", __FILE__) << "/*crawler.rb"].each{|file| require file}

def crawl_card_masters
  Source.waiting.find_each do |source_rec|
    source_rec.update(status: 1)
    card_master_crawler = CardMasterCrawler.new
    card_masters = card_master_crawler.crawl(source_rec[:list_url])
    release_date = Date.strptime(card_masters.shift, '(公開日:%Y年%m月%d日)')
    source_rec.update(release_date: release_date) if source_rec.release_date.nil?
    card_masters.each do |card_master|
      target_card_master = CardMaster.find_by(card_name_id: card_master[:card_name_id])
      if target_card_master
        target_card_master.update(status: 0)
        next
      end

      CardMaster.create(card_master)
    end
    source_rec.update(status: 2)
  rescue => e
    pp e.class
    pp e.message
    pp e.backtrace
    source_rec.update(status: 3)
    Log.create_log_record(
      category: 'source',
      paramater_id: source_rec.id,
      event_name: e.class,
      message: "#{e.message}\n#{e.backtrace}"
    )
  end
end

def crawl_cards
  CardMaster.waiting.find_each do |card_master_rec|
    card_master_rec.update(status: 1)
    card_crawler = CardsCrawler.new
    cards = card_crawler.crawl(card_master_rec[:detail_url])
    cards.each do |card_master|
      next if Card.exists?(key_number: card_master[:key_number])

      Card.create(card_master)
    end
    card_master_rec.update(status: 2)
  rescue => e
    pp e.class
    pp e.message
    pp e.backtrace
    card_master_rec.update(status: 3)
    Log.create_log_record(
      category: 'card_master',
      paramater_id: card_master_rec.id,
      event_name: e.class,
      message: "#{e.message}\n#{e.backtrace}"
    )
  end
end

def crawl_pages
  CardMaster.crawled.find_each do |card_master_rec|
    card_master_rec.update(status: 4)
    Site.all.find_each do |site_rec|
      page_crawler = BasePageCrawler.factory(site_rec.site_code)
      page_hash_list = page_crawler.crawl(card_master_rec)
      page_hash_list.each do |page_hash|
        target_card = Card.find(page_hash[:card_id])

        if site_rec.site_code == KANABELL_CODE
          image_url = page_hash[:image_url]
          page_hash.delete(:image_url)
          target_card.update(image_url: image_url) if image_url
        end

        next if Page.exists?(url: page_hash[:url], model_number: page_hash[:model_number])

        Page.create(page_hash)
        target_card.update(Site.crawled(site_rec.site_code))
      end
    end
    card_master_rec.update(status: 5)
  rescue => e
    pp e.class
    pp e.message
    pp e.backtrace
    card_master_rec.update(status: 6)
    Log.create_log_record(
      site: site_rec.ja_name,
      category: 'card_master',
      paramater_id: card_master_rec.id,
      event_name: e.class,
      message: "#{e.message}\n#{e.backtrace}"
    )
  end
end

def crawl_waiting?
 Source.waiting.exists? || CardMaster.waiting.exists? || CardMaster.crawled.exists?
end

loop do
  begin
    source_crawler = SourceCrawler.new
    sources = source_crawler.crawl_new
    if Source.create_new?(sources) || crawl_waiting?

      puts "カードマスタークロール開始 #{Time.now}"
      crawl_card_masters
      puts "カードマスタークロール終了 #{Time.now}"

      puts "カードクロール開始 #{Time.now}"
      crawl_cards
      puts "カードクロール終了 #{Time.now}"

      puts "ページクロール開始 #{Time.now}"
      crawl_pages
      puts "ページクロール終了 #{Time.now}"
  
    else
      puts "新情報待ち #{Time.now}"
      sleep 1800
      next
    end
  rescue => e
    pp e.class
    pp e.message
    pp e.backtrace
    Log.create_log_record(event_name: e.class, message: "#{e.message}\n#{e.backtrace}")
  end
end
