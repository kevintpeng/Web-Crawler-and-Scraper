module Crawlify
  require 'pathname'
  require 'rest-client'
  CONFIG = {}
  ROOT = File.expand_path('../', __FILE__)
  # fetch all configurations
  Pathname.new(File.expand_path("#{ROOT}/config").children.select(&:directory?).each do |path|
    config_name = File.basename(path).downcase
    CONFIG[config_name] = path
  end

  class Crawler
    def initializer(path, options)
      @stop = options[:stop] = nil # defines a terminating state, where crawl fails
      @path = path
      @name = File.basename(path)
      @headers = Crawlify.parse_headers(File.read("#{@path}/headers"))
      @output = "#{Crawlify::ROOT}/output/#{@name}"
    end

    def crawl(resource_path, url)
      body = RestClient.get(url, @headers).body
      return if body =~ @stop
      save(resource_path, body)
      # parse html
    end

    # fetches and saves resource
    def save(resource_path, body)
      output_path = File.expand_path(@output, resource_path)
      File.open(output_path, 'wb') do |fo|
        fo.write body
      end
    end
  end

  def self.parse_headers(string)
    headers = {}
    string.lines.each do |header|
      match = header.match(/^(.*?):(.*)$/)
      next unless match
      key = match[1].gsub('-', '_').strip.downcase.to_s
      val = match[2]
      headers[key] = val
    end
    headers
  end
end
