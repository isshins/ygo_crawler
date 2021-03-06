require 'nokogiri'
require 'open-uri'
require 'open3'

class CurlError < StandardError; end

class BaseCardCrawler
  BASE_URL = 'https://www.db.yugioh-card.com/'

  def open(url)
    sleep 1
    stdout, stderr, status = Open3.capture3(curl_request(url))
    header, body = stdout&.split(/\r\n\r\n/, 2)
    raise CurlError, stdout if !status.success? || header.nil?

    status_code = header.split(/\r\n/)[0].split(' ')[1].to_i
    html = body
    doc = Nokogiri::HTML.parse(html, nil, 'UTF-8')

    { html: html, doc: doc, status_code: status_code}
  end

  def curl_request(url)
    <<~CURL
  curl -si "#{url}" \
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
