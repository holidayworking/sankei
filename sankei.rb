#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'data_mapper'
require 'dm-migrations'
require 'feed-normalizer'
require 'nokogiri'
require 'open-uri'
require 'yaml'

class News
  include DataMapper::Resource

  property :id,             Serial
  property :title,          String
  property :url,            URI
  property :content,        Text
  property :date_published, DateTime

  belongs_to :category
end

class Category
  include DataMapper::Resource

  property :id,   Serial
  property :name, String

  has 1, :news
end

base = File.expand_path(File.dirname(__FILE__))
filename = File.exist?("#{base}/config.yml") ? 'config.yml' : 'config.default.yml'
config = YAML.load(File.read(filename))

DataMapper.setup(:default, config['database'])
DataMapper.finalize
DataMapper.auto_upgrade!

feed = FeedNormalizer::FeedNormalizer.parse(open(config['source']['feed']))
feed.entries.each do |entry|
  if News.first(:url => entry.url)
    puts "Skip: #{entry.url}"
    next
  end

  puts "Fetch: #{entry.url}"

  begin
    doc = Nokogiri::HTML(open(entry.url))
    content = doc.css(config['source']['css']).inner_text.gsub(/\r\n|\r|\n/, '')
  rescue
    next
  end

  category = Category.first_or_create(:name => entry.categories.first)

  news = News.create(
    :title          => entry.title,
    :url            => entry.url,
    :content        => content,
    :category       => category,
    :date_published => entry.date_published
  )
end
