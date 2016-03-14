#!/bin/env ruby
# encoding: utf-8

require 'nokogiri'
require 'open-uri'
require 'scraperwiki'
require 'pry'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end


def noko_for(url)
  Nokogiri::HTML(open(url).read) 
end

def scrape_list(url)
  noko = noko_for(url)
  warn url

  # Scrape members
  noko.css('a[href*="/the-national-assembly/members/item/"]/@href').map(&:text).uniq.each do |href|
    scrape_mp(URI.join url, href)
  end

  # Next page
  unless (next_url = noko.css('li.pagination-next a/@href')).empty?
    scrape_list(URI.join url, next_url.text)
  end

end

def field(noko, name)
  noko.xpath('.//text()').map(&:text).find(->{':'}) { |t| t.include? name }.split(':', 2).last.tidy 
end

def scrape_mp(url)
  noko = noko_for(url)

  sort_name = noko.css('h2.itemTitle').text.tidy
  name = sort_name.split(/\s*,\s*/, 2).reverse.join ' '

  box = noko.css('div.itemFullText')
  binding.pry if box.to_s.tidy.empty?

  data = { 
    id: url.to_s.split('/').last.split('-').first,
    name: name,
    sort_name: sort_name,
    party: field(box, 'Party'),
    county: field(box, 'County'),
    constituency: field(box, 'Constituency'),
    type: field(box, 'Type'),
    title: field(box, 'Title'),
    role: field(box, 'Role'),
    status: field(box, 'Status'),
    image: box.css('img/@src').map { |i| i.text }.first,
    source: url.to_s,
  }
  data[:image] = URI.join(url, data[:image]).to_s unless data[:image].to_s.empty?

  ScraperWiki.save_sqlite([:id], data)
end

scrape_list('http://www.parliament.go.ke/the-national-assembly/members')
