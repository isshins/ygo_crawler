require_relative '../../config/common'
require_relative './source_crawler'
require_relative './card_master_crawler'
require_relative './cards_crawler'

loop do
  begin
    if Source.waiting.exists? || CardMaster.waiting.exists?
      sources = SourceCrawler.new.crawl_new
      sources.each do |source|
        next if Source.exists?(pack_id: source[:pack_id])

        Source.create(source)
      end

      Source.waiting.find_each do |source_rec|
        begin
          source_rec.update(status: 1)
          card_masters = CardMasterCrawler.new.crawl(source_rec[:list_url])
          release_date = Date.strptime(card_masters.shift, '(公開日:%Y年%m月%d日)')
          source_rec.update(release_date: release_date) if source_rec.release_date.nil?
          card_masters.each do |card_master|
            next if CardMaster.exists?(card_id: card_master[:card_id])

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

      CardMaster.waiting.find_each do |card_master_rec|
        begin
          card_master_rec.update(status: 1)
          cards = CardsCrawler.new.crawl(card_master_rec[:detail_url])
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
    else
      puts "新情報待ち"
      sleep 600
      next
    end
  rescue => e
    pp e.class
    pp e.message
    pp e.backtrace
    Log.create_log_record(error: e)
  end
end
