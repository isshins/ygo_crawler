require_relative 'base_card_crawler'

class CardsCrawler < BaseCardCrawler
  def crawl(detail_url)
    card_hash_list  = []
    html_info = open(detail_url)

    card_name = html_info[:doc].css('#pan_nav li').last.text
    html_info[:doc].css('#update_list .inside').each do |pack_tag|
      card_hash = {}
      model_number = pack_tag.at_css('.card_number').text.gsub(/[[:space:]]/, '')
      list_href = pack_tag.at_css('.link_value')[:value]
      detail_uri = URI(detail_url)
      source_uri = URI.join(BASE_URL, list_href)
      keys = [:card_name_id, :pack_id, :rarity, :illust_id]

      card_hash[:card_name_id] = Hash[URI.decode_www_form(detail_uri.query)]['cid']
      card_hash[:pack_id] = Hash[URI.decode_www_form(source_uri.query)]['pid']
      card_hash[:card_name] = card_name
      card_hash[:model_number] = model_number unless model_number.empty?
      card_hash[:rarity] = pack_tag.at_css('.icon p').text
      card_hash[:rarity_name] = pack_tag.at_css('.icon span').text.gsub(/[[:space:]]/, '')
      card_hash[:illust_id] = crawl_illust_id(source_uri.to_s, card_name)
      card_hash[:key_number] = keys.map{|key|card_hash[key]}.join
      card_hash_list << card_hash
    end
    card_hash_list
  end

  def crawl_illust_id(list_url, card_name)
    sleep 1
    html_info = open(list_url)
    target_card = html_info[:doc].css('.t_row.c_normal').find{|card_tag| card_tag.at_css('.card_name').text == card_name}
    img_id = target_card.at_css('.box_card_img img')[:id]
    illust_id = html_info[:html][/#{img_id}.*ciid=(\d*)&enc/,1]
    illust_id
  end
end

if __FILE__ == $0
  detail_url = 'https://www.db.yugioh-card.com/yugiohdb/card_search.action?ope=2&cid=7074'
  crawler = CardsCrawler.new
  pp crawler.crawl(detail_url)
end
