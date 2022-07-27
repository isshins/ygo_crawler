require_relative '../base_page_crawler'

class KanabellCrawler < BasePageCrawler
  BASE_URL = 'https://www.ka-nabell.com/'

  def crawl(card_master_rec)
    page_hash_list = []

    list_doc = crawl_search_list(card_master_rec)
    list_doc.css('.CardListItem').each do |card_href|
      detail_url = URI.join(BASE_URL, card_href.at_css('a')[:href]).to_s
      detail_doc = open_doc(detail_url)

      model_number_text = detail_doc.at_css("td:contains('シリアル番号:')")&.text
      model_numbers = model_number_text&.gsub('シリアル番号:', '')&.split(' ')
      next if model_numbers.empty?

      image_href = detail_doc.at_css('#detail_def_img')[:src]
      image_url = URI.join(BASE_URL, image_href).to_s

      rarities = convert_rarity(card_href.at_css('.CardListRar')&.text)

      card_name_text = detail_doc.at_css('#TopicPath li:last-child').text
      alternate_art = card_name_text.include?('イラスト違い') || card_name_text.include?('パンドラ')
      opened = card_name_text.include?('開封済み')

      model_numbers.each do |model_number|
        target_cards = Card.where(model_number: model_number)
        target_cards.each do |target_card|
          rarity = rarities.find{|rarity| target_card.rarity == rarity}
          next if rarity.nil?

          same_rarity_cards = target_cards.where(rarity: rarity)

          # 同じ型番で同じレアリティで絵違いのカードを判定
          if same_rarity_cards.map(&:illust_id).uniq.length > 1
            card_id = select_alternate_id(same_rarity_cards, alternate_art)
          else
            card_id = same_rarity_cards.first.id
          end

          page_hash = {
            site_code: KANABELL_CODE,
            url: detail_url,
            image_url: image_url,
            card_id: card_id,
            card_master_id: card_master_rec.id,
            model_number: model_number,
            opened: opened,
          }
          page_hash_list << page_hash
        end
      end
    end
    page_hash_list
  end

  def convert_rarity(rarity_text)
    rarity_hash = {
      '【ノー】' => ['N'],
      '【ノレ】' => ['N'],
      '【レア】' => ['R'],
      '【パラ】' => ['P', 'M', 'KC', 'P+R'],
      '【スー】' => ['SR', 'M+SR', 'P+SR'],
      '【ウル】' => ['UR', 'M+UR', 'P+UR', 'KC+UR'],
      '【シク】' => ['SE', 'M+SE', 'P+SE', 'EXSE', 'P+EXSE', 'KC+R', '10000 SE'],
      '【アル】' => ['UL'],
      '【ホロ】' => ['HR', 'P+HR'],
      '【プリシク】' => ['PSE'],
      '【ゴル】' => ['GR', 'M+GR'],
      '【ゴルシク】' => ['GSE'],
      '【プレゴル】' => ['PG'],
      '【コレレア】' => ['CR'],
      '【20thシク】' => ['20th SE'],
    }
    rarity_hash[rarity_text]
  end

  def crawl_search_list(card_master_rec)
    card_name = card_master_rec.card_display_name.gsub(/[[:space:]]/, '')
    search_url = "#{BASE_URL}?genre=1&type=3&act=sell_search&main_card_name=#{card_name}"
    pp search_url
    search_doc = open_doc(search_url)
    card_list = search_doc.css('thead th > div > a')
    target_card_name = card_list.find do |display_card_name|
      tr_hankaku(card_name) == display_card_name&.text&.gsub(/[[:space:]]/, '')
    end
    card_master_url = URI.join(BASE_URL, target_card_name[:href]).to_s
    open_doc(card_master_url)
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
  crawler = BasePageCrawler.factory(KANABELL_CODE)
  hash_list = crawler.crawl(card_master_rec)
  pp hash_list
  pp hash_list.length
end
