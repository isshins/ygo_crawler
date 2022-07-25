require_relative '../../config/common'
require_relative './source_crawler'
require_relative './card_master_crawler'
require_relative './cards_crawler'
require_relative './base_page_crawler'

def crawl_card_masters
  Source.waiting.find_each do |source_rec|
    begin
      source_rec.update(status: 1)
      card_master_crawler = CardMasterCrawler.new
      card_masters = card_master_crawler.crawl(source_rec[:list_url])
      release_date = Date.strptime(card_masters.shift, '(公開日:%Y年%m月%d日)')
      source_rec.update(release_date: release_date) if source_rec.release_date.nil?
      card_masters.each do |card_master|
        next if CardMaster.exists?(card_name_id: card_master[:card_name_id])

        CardMaster.create(card_master)
      end
      source_rec.update(status: 2)
    rescue => e
      pp e.class
      pp e.message
      pp e.backtrace
      source_rec.update(status: 3)
      Log.create_log_record(error: e, category: 'card_master')
    end
  end
end

def crawl_cards
  CardMaster.waiting.find_each do |card_master_rec|
    begin
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
      Log.create_log_record(error: e, category: 'cards')
    end
  end
end

def crawl_pages
  CardMaster.crawled.find_each do |card_master_rec|
    begin
      card_master_rec.update(status: 4)
      Site.all.find_each do |site_rec|
        page_crawler = BasePageCrawler.factory(site_rec.site_code)
        page_hash_list = page_crawler.crawl(card_master_rec)
        page_hash_list.each do |page_hash|
          next if Page.exists?(url: page_info[:page_url])

          image_url = page_info[:image_url]
          page_info.slice(:image_url)
          Card.find(id: page_info[:card_id]).update(image_url: image_url) if image_url          

          Page.create(page_info)
          )
        end
      end
      card_master_rec.update(status: 5)
    rescue => e
      pp e.class
      pp e.message
      pp e.backtrace
      card_master_rec.update(status: 6)
      Log.create_log_record(error: e, category: 'pages')
    end
  end
end

loop do
  begin
    if Source.waiting.exists? || CardMaster.waiting.exists?
      sources = SourceCrawler.new.crawl_new
      sources.each do |source|
        next if Source.exists?(pack_id: source[:pack_id])

        Source.create(source)
      end

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
      sleep 60
      next
    end
  rescue => e
    pp e.class
    pp e.message
    pp e.backtrace
    Log.create_log_record(error: e)
  end
end
