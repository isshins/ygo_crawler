require 'nokogiri'
require 'open-uri'

class SourceCrawler
  BASE_URL = 'https://www.db.yugioh-card.com/'

  def crawl
    source_hash_list = []
    html = `#{curl_request}`
    doc = Nokogiri::HTML.parse(html)
    doc.css('.pac_set').each do |source_category|
      source_hash = {}
      source_hash[:source_category] = source_category.at_css('.list_title.open span').text
      release_categories = source_category.css('.pack_m.open')
      pack_lists = source_category.css('.toggle')
      release_categories.zip(pack_lists).each do |release_category, pack_list|
        source_hash[:release_category] = release_category.text.gsub(/[[:space:]]/,'')
        pack_list.css('.pack.pack_ja').each do |pack|
          source_hash[:title] = pack.at_css('strong').text.strip
          source_hash[:sub_title] = pack.at_css('p').text.gsub(source_hash[:title], '').gsub(/[[:space:]]/,'')
          list_url_href = pack.at_css('.link_value')[:value]
          source_hash[:list_url] = URI.join(BASE_URL, list_url_href).to_s
          source_hash_list << source_hash.dup
        end
      end
    end
    source_hash_list
  end 

  def curl_request
    <<~CURL
  curl "#{BASE_URL}/yugiohdb/card_list.action" \
  -H 'authority: www.db.yugioh-card.com' \
  -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9' \
  -H 'accept-language: ja,en-US;q=0.9,en;q=0.8' \
  -H 'cache-control: max-age=0' \
  -H 'referer: https://www.db.yugioh-card.com/yugiohdb/' \
  -H 'sec-ch-ua: " Not A;Brand";v="99", "Chromium";v="102", "Google Chrome";v="102"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "macOS"' \
  -H 'sec-fetch-dest: document' \
  -H 'sec-fetch-mode: navigate' \
  -H 'sec-fetch-site: same-origin' \
  -H 'sec-fetch-user: ?1' \
  -H 'upgrade-insecure-requests: 1' \
  -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.5005.61 Safari/537.36' \
  --compressed
    CURL
  end
end

if __FILE__ == $0
  crawler = SourceCrawler.new
  pp crawler.crawl[0]
end
