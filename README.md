# Allegro Scraper (Firecrawl)

A Ruby scraper that extracts product data from [Allegro.cz](https://allegro.cz) using the [Firecrawl](https://firecrawl.dev) API.

This project was created for participation in the scraping challenge at https://deepscout-challenge.miton.cz/

## How it works

The scraper operates in two phases:

1. **Product listing pages** -- Fetches paginated product listings from the Allegro.cz notebooks category (sorted by price descending). Each page yields up to 60 products with their name, URL, image URL, and price.

2. **Product detail pages** -- For each product found, fetches the individual product page to extract additional data: product code and description.

HTML content is retrieved via the Firecrawl `/v2/scrape` API endpoint and parsed locally with Nokogiri. Results are written incrementally to a CSV file (`products.csv`) with the following columns:

`name`, `url`, `image_url`, `price`, `product_code`, `description`

## Prerequisites

- Ruby
- A [Firecrawl API key](https://firecrawl.dev)
- Bundler

## Setup

```sh
bundle install
cp .env.example .env
```

Add your Firecrawl API key to `.env`:

```
FIRECRAWL_API_KEY=your_key_here
```

## Usage

```sh
ruby scraper.rb
```

The scraper will output progress to stdout and write results to `products.csv`.
