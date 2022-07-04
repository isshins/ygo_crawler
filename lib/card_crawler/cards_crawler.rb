require_relative 'base_card_crawler'

class CardsCrawler < BaseCardCrawler
  def crawl(detail_url)
    card_hash_list  = []
    detail_html = `#{curl_request(detail_url)}`
    doc = Nokogiri::HTML.parse(detail_html)
    card_ruby = doc.at_css('.ruby').text
    doc.css('#update_list .inside').each do |pack_tag|
      card_hash = {}
      model_number = pack_tag.at_css('.card_number').text.gsub(/[[:space:]]/, '')
      list_href = pack_tag.at_css('.link_value')[:value]
      source_url = URI.join(BASE_URL, list_href).to_s
      card_hash[:card_name] = card_ruby
      card_hash[:model_number] = model_number unless model_number.empty?
      card_hash[:rarity] = pack_tag.at_css('.icon p').text
      card_hash[:rarity_name] = pack_tag.at_css('.icon span').text.gsub(/[[:space:]]/, '')
      card_hash[:source_url] = source_url # 一つ上の階層でマッチするsourceレコードのidを挿入する
      card_hash[:illust_id] = crawl_illust_id(source_url, card_ruby)
      card_hash_list << card_hash
    end
    card_hash_list
  end

  def crawl_illust_id(list_url, card_ruby)
    sleep 1
    list_html = `#{curl_request(list_url)}`
    list_doc = Nokogiri::HTML.parse(list_html)
    target_card = list_doc.css('.t_row.c_normal').find{|card_tag| card_tag.at_css('.card_ruby').text == card_ruby}
    img_id = target_card.at_css('.box_card_img img')[:id]
    illust_id = list_html[/#{img_id}.*ciid=(\d*)&enc/,1]
    illust_id
  end
end

if __FILE__ == $0
  detail_url = 'https://www.db.yugioh-card.com/yugiohdb/card_search.action?ope=2&cid=4041'
  crawler = CardsCrawler.new
  pp crawler.crawl(detail_url)
end
