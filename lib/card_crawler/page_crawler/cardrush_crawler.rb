require_relative '../base_page_crawler'

class CardRushCrawler < BasePageCrawler
  BASE_URL = 'https://www.cardrush.jp/'

  def crawl(card_master_rec, page_num = 1)
    page_hash_list = []
    card_name = tr_hankaku(card_master_rec.card_display_name).gsub(/[[:space:]]/, '')
    list_url = "https://www.cardrush.jp/product-list/0/0/photo?keyword=#{card_name}&page=#{page_num}"
    list_doc = open_doc(list_url)
    target_cards = Card.where(card_name_id: card_master_rec.card_name_id, cardrush: 0)
    model_numbers = target_cards.pluck(:model_number).uniq.compact
    list_doc.css('.itemlist_box.clearfix li').each do |card|
      card_name_text = card.at_css('.goods_name').text
      model_number = model_numbers.find{|model_number| card_name_text.include?(model_number)}
      next if model_number.nil?

      detail_url = card.at_css('a')[:href]
      rarity = convert_rarity(card_name_text)
      alternate_art = card_name_text.include?('(新)') || card_name_text.include?('パンドラver')
      not_opened = card_name_text.include?('未開封')
      card_status = card_name_text[/〔状態(.*)〕/, 1]
      same_rarity_cards = target_cards.where(model_number: model_number, rarity: rarity)

      # 同じ型番で同じレアリティで絵違いのカードを判定
      if same_rarity_cards.map(&:illust_id).uniq.length > 1
        card_id = select_alternate_id(same_rarity_cards, alternate_art)
      else
        card_id = same_rarity_cards.first.id
      end

      page_hash = {
        site_code: CARDRUSH_CODE,
        url: detail_url,
        model_number: model_number,
        card_id: card_id,
        card_master_id: card_master_rec.id,
        not_opened: not_opened,
        card_status: card_status
      }
      page_hash_list << page_hash
    end
    pp "card_rush:#{page_num}ページ目"
    page_hash_list.concat(crawl(card_master_rec, page_num + 1)) if list_doc.at_css('.to_next_page')
    page_hash_list
  end

  def convert_rarity(card_name_text)
    rarity_list = [
      ['DBLE-JPS0', 'P+EXSE'],
      ['【ノーマル】', 'N'],
      ['【ノーマルレア】', 'N'],
      ['【レア】', 'R'],
      ['【ノーマルパラレル】', 'P'],
      ['【レアパラレル】', 'P+R'],
      ['【ミレニアム】', 'M'],
      ['【KC】', 'KC'],
      ['【スーパー】', 'SR'],
      ['【スーパーパラレル】', 'P+SR'],
      ['【ミレニアムスーパー】', 'M+SR'],
      ['【ウルトラ】', 'UR'],
      ['【KCウルトラ】', 'KC+UR'],
      ['【ミレニアムウルトラ】', 'M+UR'],
      ['【ウルトラパラレル】', 'P+UR'],
      ['【シークレット】', 'SE'],
      ['【ミレニアムシークレット】', 'M+SE'],
      ['【シークレットパラレル】', 'P+SE'],
      ['【シークレット】', 'SE'],
      ['【KCレア】', 'KC+R'],
      ['【エクストラシークレット】', 'EXSE'],
      ['【レリーフ】', 'UL'],
      ['【ホログラフィック】', 'HR'],
      ['【ホログラフィックパラレル】', 'P+HR'],
      ['【プリズマティックシークレット】', 'PSE'],
      ['【ゴールド】', 'GR'],
      ['【ミレニアムゴールド】', 'M+GR'],
      ['【ゴルシク】', 'GSE'],
      ['【プレミアムゴールド】', 'PG'],
      ['【コレクターズ】', 'CR'],
      ['【20thシークレット】', '20thSE'],
      ['【10000シークレット】', '10000SE']
    ]
    rarity_list.each{|rarity_text, rarity| return rarity if card_name_text.include?(rarity_text)}
  end

  def tr_hankaku(string)
    string.tr('〜％！？０-９', '~%!?0-9').gsub('：／＜＞・-ー', '')
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
  crawler = BasePageCrawler.factory(CARDRUSH_CODE)
  hash_list = crawler.crawl(card_master_rec)
  pp hash_list.sort_by{|hash| hash[:card_id]}.uniq{|hash| hash[:url]}
  pp hash_list.length
end

