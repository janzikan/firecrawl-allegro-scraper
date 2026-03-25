# frozen_string_literal: true

require 'csv'
require 'dotenv/load'
require 'http'
require 'json'
require 'logger'
require 'nokogiri'

FIRECRAWL_API_KEY = ENV.fetch('FIRECRAWL_API_KEY')

# Firecrawl API client
class FirecrawlClient
  API_BASE_URL = 'https://api.firecrawl.dev'
  API_ENDPOINT = '/v2/scrape'

  def initialize(api_key)
    headers = {
      'Authorization' => "Bearer #{api_key}",
      'Content-Type' => 'application/json'
    }

    @client = HTTP.persistent(API_BASE_URL).headers(headers)
  end

  def scrape(url)
    response = @client.post(API_ENDPOINT, json: request_params(url: url))
    JSON.parse(response.body)
  end

  private

  def request_params(hsh)
    hsh.merge(default_request_params)
  end

  def default_request_params
    {
      'onlyMainContent' => true,
      'formats' => ['html']
    }
  end
end

# Extracts data from Allegro product list and product details HTML
class AllegroParser
  PRODUCT_CODE_PATTERN = /Kód produktu\s*:?\s*(.+?\[\*\(.+?\)\*\])/m.freeze

  def products(html)
    doc = Nokogiri::HTML(html)
    doc.css('article').map { |article| parse_product(article) }.compact
  end

  def product_details(html)
    doc = Nokogiri::HTML(html)

    description_el = doc.at_css('[itemprop="description"]')
    description = description_el&.text&.strip
    description = nil if description&.empty?

    code_match = description&.match(PRODUCT_CODE_PATTERN)

    {
      product_code: code_match ? code_match[1] : nil,
      description: description
    }
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

SOURCE_URL = 'https://allegro.cz/kategorie/pocitace-notebooky-491?order=pd&p=%s'
ITEMS_TO_SCRAPE = 1_000
ITEMS_PER_PAGE = 60

CSV_FILE = 'products.csv'
CSV_COLUMNS = %i[name url image_url price product_code description].freeze

puts '=== Allegro Scraper (Firecrawl) ==='

scraper = FirecrawlClient.new(FIRECRAWL_API_KEY)
parser = AllegroParser.new

csv = CSV.open(CSV_FILE, 'w')
csv << CSV_COLUMNS.map(&:to_s)

# How many pages we need to scrape to get all the items
pages_to_scrape = (ITEMS_TO_SCRAPE.to_f / ITEMS_PER_PAGE).ceil

13.upto(pages_to_scrape) do |i|
  product_list_url = SOURCE_URL % i
  puts "Scraping product list page: #{product_list_url}"

  # Scrape product list page
  json = scraper.scrape(product_list_url)
  products = parser.products(json.dig('data', 'html'))
  puts "Products found: #{products.length}"

  # Scrape product details pages
  # We have to scrape pages one by one, because of the Firecrawl API rate limits
  # https://docs.firecrawl.dev/rate-limits
  puts 'Scraping product details pages'
  products.each do |product|
    url = product[:url]
    puts url

    json = scraper.scrape(url)
    details = parser.product_details(json.dig('data', 'html'))
    data = product.merge(details)

    csv << CSV_COLUMNS.map { |col| data[col] }
    csv.flush
  end
end

csv.close
puts "Data saved to #{CSV_FILE}"
