require_relative '../base_page_crawler'

class YuyuteiCrawler < BasePageCrawler
  BASE_URL = 'https://yuyu-tei.jp/'

  def crawl(card_master_rec)
    page_hash_list = []
    card_name = tr_hankaku(card_master_rec.card_display_name)
    list_url = "https://yuyu-tei.jp/game_ygo/sell/sell_price.php?name=#{card_name}&kizu=0"
    list_doc = open_doc(list_url)
    target_cards = Card.where(card_name_id: card_master_rec.card_name_id)
    model_numbers = target_cards.pluck(:model_number).compact.uniq
    raritiy_lists = list_doc.css('.card_list_box > div')
    raritiy_lists.each do |raritiy_list|
      display_rarity = raritiy_list.at_css('.gr_color').text
      rarity = convert_rarity(display_rarity)
      raritiy_list.css('.card_list > li').each do |card|
        card_href = card.at_css('.id a')
        model_number = card_href.text.gsub(/[[:space:]]/, '')
        next unless model_numbers.include?(model_number)

        detail_url = URI.join(BASE_URL, card_href[:href]).to_s

        card_name_text = card.at_css('.image img')[:alt]
        alternate_art = card_name_text.include?('イラスト違い') || card_name_text.include?('右向き')

        same_rarity_cards = target_cards.where(model_number: model_number, rarity: rarity)
        if same_rarity_cards.empty?
          Log.create_log_record(event_name: 'rarity error', category: 'card_master', paramater_id: card_master_rec.card_name_id)
          next
        end

        if same_rarity_cards.map(&:illust_id).uniq.length > 1
          card_id = select_alternate_id(same_rarity_cards, alternate_art)
        else
          card_id = same_rarity_cards.first.id
        end

        page_hash = {
          site_code: YUYUTEI_CODE,
          url: detail_url,
          model_number: model_number,
          card_id: card_id,
        }
        page_hash_list << page_hash
      end
    end
    page_hash_list
  end

  def convert_rarity(rarity_text)
    rarity_text.gsub('-N', '').tr('-', '+')
  end

  def curl_request(url)
    <<~CURL
  curl -si "#{url}" \
  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9' \
  -H 'Accept-Language: ja,en-US;q=0.9,en;q=0.8' \
  -H 'Cache-Control: max-age=0' \
  -H 'Connection: keep-alive' \
  -H 'Sec-Fetch-Dest: document' \
  -H 'Sec-Fetch-Mode: navigate' \
  -H 'Sec-Fetch-Site: same-origin' \
  -H 'Sec-Fetch-User: ?1' \
  -H 'Upgrade-Insecure-Requests: 1' \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36' \
  -H 'sec-ch-ua: ".Not/A)Brand";v="99", "Google Chrome";v="103", "Chromium";v="103"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "macOS"' \
  --compressed
    CURL
  end
end

if __FILE__ == $0
  card_name = 'ブラック・マジシャン'
  card_master_rec = CardMaster.find_by(card_display_name: card_name)
  crawler = BasePageCrawler.factory(YUYUTEI_CODE)
  hash_list = crawler.crawl(card_master_rec)
  pp hash_list
  pp hash_list.length
end
