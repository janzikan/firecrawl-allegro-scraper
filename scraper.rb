# frozen_string_literal: true

require 'dotenv/load'
require 'http'
require 'json'
require 'logger'
require 'nokogiri'

FIRECRAWL_API_KEY = ENV.fetch('FIRECRAWL_API_KEY')

# Firecrawl API client
class FirecrawlClient
  API_BASE_URL = 'https://api.firecrawl.dev'
  API_ENDPOINT_SCRAPE = '/v2/scrape'
  API_ENDPOINT_BATCH_SCRAPE = '/v2/batch/scrape'

  def initialize(api_key)
    headers = {
      'Authorization' => "Bearer #{api_key}",
      'Content-Type' => 'application/json'
    }

    @client = HTTP.persistent(API_BASE_URL).headers(headers)
  end

  def scrape(url)
    response = @client.post(API_ENDPOINT_SCRAPE, json: request_params(url: url))
    JSON.parse(response.body)
    # JSON.parse(File.read('firecrawl.json'))
  end

  def batch_scrape(urls)
    response = @client.post(API_ENDPOINT_BATCH_SCRAPE, json: request_params(urls: urls))
    JSON.parse(response.body)
  end

  private

  def request_params(hsh)
    hsh.merge(default_request_params)
  end

  def default_request_params
    {
      'onlyMainContent': true,
      'mobile' => false,
      'formats' => ['html'],
      'location' => { 'country': 'CZ', 'languages': ['cs-CZ'] }
    }
  end
end

# Extracts data from Allegro product listing and product details HTML
class AllegroParser
  def products(html)
    doc = Nokogiri::HTML(html)
    doc.css('article').map { |article| parse_product(article) }.compact
  end

  def product_details(html)
    doc = Nokogiri::HTML(html)
  end

  private

  def parse_product(article)
    link = article.at_css('h2 a')
    return nil unless link

    price_el = article.at_css('p[aria-label*="aktuální cena"]')
    img = article.at_css('img[alt]')

    {
      name: link.text.strip,
      url: link['href'],
      image_url: img&.[]('src'),
      price: extract_price(price_el)
    }
  end

  def extract_price(element)
    return nil unless element

    element.text.gsub("\u00A0", ' ').strip
  end
end

# Main routine

SOURCE_URL = 'https://allegro.cz/kategorie/pocitace-notebooky-491?order=pd'
ITEMS_TO_SCRAPE = 1_000
ITEMS_PER_PAGE = 60

puts '=== Allegro.cz Scraper (Firecrawl) ==='
puts

client = FirecrawlClient.new(FIRECRAWL_API_KEY)
json = client.scrape(SOURCE_URL)

parser = AllegroParser.new
products = parser.products(json.dig('data', 'html'))

File.write('products.json', JSON.pretty_generate(products))
puts "Saved #{products.length} products to products.json"
