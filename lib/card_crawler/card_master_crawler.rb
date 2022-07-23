require_relative 'base_card_crawler'

class CardMasterCrawler < BaseCardCrawler
  def crawl(url)
    html_info = open(url)
    ## Sourceの発売日を出力の先頭に埋め込む
    card_hash_list = [html_info[:doc].at_css('#previewed')&.text&.gsub(/[[:space:]]/, '')]
    html_info[:doc].css('.t_row.c_normal').each do |card|
      species_and_other = card.at_css('.card_info_species_and_other_item')&.text&.gsub(/[[:space:]]/, '')
      type_info = parse_type(species_and_other)
      detail_uri = URI.join(BASE_URL, card.at_css('.link_value')[:value])
       
      card_hash = {
        card_name_id: Hash[URI.decode_www_form(detail_uri.query)]['cid'],
        card_ruby: card.at_css('.card_ruby').text,
        card_display_name: card.at_css('.card_name').text,
        card_attribute: card.at_css('.box_card_attribute').text.gsub(/[[:space:]]/, ''),
        level: card.at_css('.box_card_level_rank')&.text&.gsub(/\D/,''),
        link_num: card.at_css('.box_card_linkmarker')&.text,
        species: type_info[:species],
        is_effective: type_info[:is_effective],
        monster_type: type_info[:monster_type],
        sub_monster_type1: type_info[:sub_monster_type1],
        sub_monster_type2: type_info[:sub_monster_type2],
        text: card.at_css('.box_card_text.c_text.flex_1').text&.gsub(/[[:space:]]/, ''),
        pendulum_text: card.at_css('.box_card_pen_effect.c_text.flex_1')&.text&.gsub(/[[:space:]]/, ''),
        atk: card.at_css('.atk_power')&.text&.gsub('攻撃力', '')&.gsub(/[[:space:]]/, ''),
        def: card.at_css('.def_power')&.text&.gsub('守備力', '')&.gsub(/[[:space:]]/, ''),
        pendulum_scale: card.at_css('.box_card_pen_scale')&.text&.gsub(/\D/,''), 
        detail_url: detail_uri.to_s,
      }

      if card_hash[:link_num]
        link_marker = card.at_css('.box_card_linkmarker img')[:src][/link(\d*).png/, 1]
        card_hash[:link_marker] = link_marker
      end

      if card_hash[:card_attribute] == '魔法' || card_hash[:card_attribute] == '罠'
        spell_type = card.at_css('.box_card_effect')&.text&.gsub(/[[:space:]]/, '')
        spell_type = '通常' if spell_type.nil?
        card_hash[:spell_type] = spell_type
      end
      card_hash_list << card_hash
    end
    card_hash_list
  end 

  def parse_type(species_and_other)
    type_info = {}
    return type_info if species_and_other.nil?

    extra = ['儀式', '融合', 'シンクロ', 'エクシーズ', 'リンク']
    type_info[:monster_type] = 'メイン'
    type_list = species_and_other.gsub(/【|】/, '').split('／')
    type_list.each do |type|
      if type.include?('族') 
        type_info[:species] = type
      elsif type == '通常' 
        type_info[:is_effective] = false
      elsif type == '効果'
        then type_info[:is_effective] = true
      elsif extra.include?(type)
        type_info[:monster_type] = type
      else 
        type_info[:sub_monster_type2] = type if type_info[:sub_monster_type1]
        type_info[:sub_monster_type1] = type if type_info[:sub_monster_type2].nil?
      end
    end
    type_info
  end
end

if __FILE__ == $0
  url = 'https://www.db.yugioh-card.com/yugiohdb/card_search.action?ope=1&sess=1&pid=1000008603000&rp=99999'
  crawler = CardMasterCrawler.new
  pp crawler.crawl(url)[0..3]
end
