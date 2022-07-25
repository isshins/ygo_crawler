require 'nokogiri'
require 'open-uri'
require 'open3'
require_relative '../../config/common'

class CurlError < StandardError; end

class BasePageCrawler
  def self.factory(site)
    case site
    when KANABELL_CODE
      KanabellCrawler.new()
    when YUYUTEI_CODE
      YuyuteiCrawler.new()
    when CARDRUSH_CODE
      CardRushCrawler.new()
    end
  end

  def open_doc(url)
    sleep 1
    stdout, stderr, status = Open3.capture3(curl_request(url))
    header, body = stdout&.split(/\r\n\r\n/, 2)
    raise CurlError, stdout if !status.success? || header.nil?

    status_code = header.split(/\r\n/)[0].split(' ')[1].to_i
    html = body
    Nokogiri::HTML.parse(html, nil, 'UTF-8')
  end

  def fetch_html(url)
    sleep 1
    tdout, stderr, status = Open3.capture3(curl_request(url))
    header, body = stdout&.split(/\r\n\r\n/, 2)
    raise CurlError, stdout if !status.success? || header.nil?

    body
  end

  def curl_request(_url)
    raise "Called abstract method: #{__method__}"
  end
end
