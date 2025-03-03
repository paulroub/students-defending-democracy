# frozen_string_literal: true

# Fetches the links from a Linktree page and generate markdown files
# in the site's _links directory.

# This will almost certainly break in the future when Linktree changes their
# payload format. The way of web-scraping.

# If so, please file an issue here, including the URL you were trying to capture:
# https://github.com/paulroub/linky/issues

# usage:
#     bundle exec ruby get_links.rb <linktree-url>

require 'json'
require 'nokogiri'
require 'open-uri'
require 'fileutils'

LINK_ROOT = '../_links'
IMAGE_ROOT = '../images'
IMAGE_WEB_ROOT = '/images'

raise ArgumentError, 'usage: ruby get_links.rb <linktree-url>' unless ARGV.length == 1

def build_links(linktree_url)
  links = collect_link_definitions(linktree_url)

  links.each do |source_link|
    capture_link(LINK_ROOT, IMAGE_ROOT, IMAGE_WEB_ROOT, source_link)
  end
end

def collect_link_definitions(linktree_page_url)
  puts "Collecting links from #{linktree_page_url}..."
  response = URI.parse(linktree_page_url).open(
    {
      'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) ' \
                      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/'
    }
  )
  soup = Nokogiri::HTML(response.read)

  data_block = soup.css('script[type="application/json"]').first
  data = JSON.parse(data_block.text)

  all_links = data['props']['pageProps']['links']

  groups_by_id = build_group_lookup(all_links)

  valid_links = all_links.select { |link| link['url'] and !link['url'].empty? }

  valid_links.each do |link|
    if link['parent']
      parent_id = link['parent']['id'].to_s
      link['category'] = groups_by_id[parent_id] if groups_by_id[parent_id]
    end
  end

  valid_links
end

def build_group_lookup(all_links)
  groups = all_links.select { |link| link['type'] == 'GROUP' }

  groups_by_id = {}

  groups.each do |group|
    groups_by_id[group['id']] = group['title']
  end

  groups_by_id
end

def capture_link(link_root, image_root, image_web_root, link)
  priority = link['position'] + 1
  img_fn = nil
  image_link = nil
  category = nil

  puts "Collecting #{link['title']}..."

  img = link['thumbnail'] || (link['modifiers'] && link['modifiers']['thumbnailImage'])

  if img
    puts '   ...downloading thumbnail'
    img_name = File.basename(img)
    img_fn = "#{image_root}/#{img_name}"
    image_link = "#{image_web_root}/#{img_name}"

    File.write(img_fn, URI.parse(img).open.read, mode: 'wb')
  end

  category = link['category'] if link['category']

  stub = stub_title(link['title'])
  link_fn = "#{link_root}/#{stub}.md"

  create_link_file(link['url'], priority, link['title'], img_fn, image_link, link_fn, category)
end

def create_link_file(url, priority, title, img_fn, image_link, link_fn, category)
  File.open(link_fn, 'w:utf-8') do |f|
    f.puts '---'
    f.puts "title: #{title}"
    f.puts "link: #{url}"
    f.puts "priority: #{priority}"
    f.puts "image: #{image_link}" if img_fn
    f.puts "category: #{category}" if category
    f.puts '---'
    f.puts ''
  end
end

def stub_title(title)
  title.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-+|-+$/, '')
end

build_links(ARGV[0])
