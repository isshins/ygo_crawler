require_relative 'base_card_crawler'

class SourceCrawler < BaseCardCrawler
  def crawl_new(all = false)
    source_hash_list = []
    url = URI.join(BASE_URL, '/yugiohdb/card_list.action').to_s
    html_info = open(url)
    html_info[:doc].css('.pac_set').each do |source_category|
      next if source_category.at_css('.new').nil? && !all

      source_hash = {}
      source_hash[:source_category] = source_category.at_css('.list_title.open span').text
      release_categories = source_category.css('.pack_m.open')
      pack_lists = source_category.css('.toggle')
      release_categories.zip(pack_lists).each do |release_category, pack_list|
        next if pack_list.at_css('.new').nil? && !all

        source_hash[:release_category] = release_category.text.gsub(/[[:space:]]/,'')
        pack_list.css('.pack.pack_ja').each do |pack|
          next if pack.at_css('.new').nil? && !all

          source_hash[:title] = pack.at_css('strong').text.strip
          source_hash[:sub_title] = pack.at_css('p').text.gsub(source_hash[:title], '').gsub(/[[:space:]]/,'')
          list_url_href = pack.at_css('.link_value')[:value]
          list_uri = URI.join(BASE_URL, list_url_href)
          source_hash[:list_url] = list_uri.to_s
          source_hash[:pack_id] = Hash[URI.decode_www_form(list_uri.query)]['pid']
          source_hash_list << source_hash.dup
        end
      end
    end
    source_hash_list
  end 
end

if __FILE__ == $0
  crawler = SourceCrawler.new
  pp crawler.crawl_new
end
