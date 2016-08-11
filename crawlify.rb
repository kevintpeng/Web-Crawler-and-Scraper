module Crawlify
  require 'pathname'
  require 'fileutils'
  require 'rest-client'
  require 'nokogiri'

  CONFIG = {}
  ROOT = File.expand_path('../', __FILE__)
  # fetch all configurations
  Pathname.new(File.expand_path("#{ROOT}/config")).children.select(&:directory?).each do |path|
    config_name = File.basename(path).downcase
    CONFIG[config_name] = path
  end

  class Crawler
    def initialize(name, options = {})
      @stop = options[:stop] || nil # defines a terminating state, where crawl fails
      @path = "#{Crawlify::ROOT}/config/#{name}"
      @name = name
      @headers = Crawlify.parse_headers(File.read("#{@path}/headers"))
      @output = "#{Crawlify::ROOT}/output/#{@name}"
      @doc_type = options[:doc_type] || 'html'
      @seen = []
    end

    def crawl(resource_path, url)
      @seen << resource_path # make this a mapping
      puts "#CRAWL  #{resource_path} => #{url}"
      base_directory = File.dirname(resource_path)
      base_url = url.match(%r{^https?://([^/]*)})[0]
      body = begin
        RestClient.get(url, @headers).body
      rescue RestClient::Forbidden
        puts "#CRAWL::403 from #{url}"
        return
      end

      # since we're pulling all sorts of files, we need to check encoding before matching against regex
      return if @stop && body.valid_encoding? && body =~ @stop

      # parse html
      if @doc_type == 'html' && resource_path =~ /(html|HTML)$/
        doc = Nokogiri::HTML(body)
        js = Crawlify.all_src_for_tag(doc, 'script')
        img = Crawlify.all_src_for_tag(doc, 'img')
        a = C
        links = doc.xpath("//a/@onclick").to_a.map { |e| (e.to_s.match(/window\.open\('([^']*?)',/) || [])[1] }.compact
        to_crawl = (js + img + links).uniq
        puts to_crawl
        to_crawl.each do |resource|

          # gsub if @seen.include? "#{base}#{resource}", else

          crawl("#{base_directory}#{resource}", "#{base_url}/#{resource}")
        end
      end
      save(resource_path, body)
      true
    end

    # fetches and saves resource
    def save(resource_path, body)
      output_path = "#{@output}/#{resource_path}"
      return if File.exists? output_path
      required_dirs = base_path(output_path)
      FileUtils.mkdir_p(required_dirs) unless Dir.exists? required_dirs
      File.open(output_path, 'wb') do |fo|
        fo.write body
      end
    end

    def zip
      system("zip -r #{@output}_crawlify #{@output}")
    end
  end


  def self.relative_path(from, to)
    if to[0] == '/'
      relative = File.dirname(from).gsub(%r{/([^/]*)}, "../")
      "#{relative}#{to}"
    else
      to
    end
  end

  def self.parse_headers(string)
    headers = {}
    string.lines.each do |header|
      match = header.match(/^(.*?):(.*)$/)
      next unless match
      key = match[1].gsub('-', '_').strip.downcase.to_s
      val = match[2].strip
      headers[key] = val
    end
    headers
  end

  def self.all_tag_header(doc, tag, header)
    doc.xpath("//#{tag}/#{header}").to_a.map(&:to_s)
  end
end
