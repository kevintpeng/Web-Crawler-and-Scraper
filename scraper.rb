# for scraping
require 'rest-client' 	#http requests
require 'sanitize'		#html sanitization
require 'htmlentities' 	#html decoding

# for inserting to database
require 'active_record'
require 'activerecord-import'

class Scraper
	attr_accessor :sleep_time

	def initialize(name, description = "")
		@urls = []
		@sleep_time = 0.75
		@source = name
		@description = description
	end

	def numOfLinks
		return @urls.length
	end

	def self.connectDatabase(cmd = 'cd ../../; heroku pg:credentials DATABASE')
		# CONNECT TO HEROKU-HOSTED DATABASE
		begin
			# will work assuming script is run from 2 file directories deep from root
			value = `#{cmd}` # returns the output of your command
			username = /user=.+?\s(?=)/.match(value).length != nil ? /user=.+?\s(?=)/.match(value)[0].gsub(/user=/, "").gsub(/\s/, "") : ''
			password = /password=.+?\s(?=)/.match(value).length != nil ? /password=.+?\s(?=)/.match(value)[0].gsub(/password=/, "").gsub(/\s/, "") : ''
			database = /dbname=.+?\s(?=)/.match(value).length != nil ? /dbname=.+?\s(?=)/.match(value)[0].gsub(/dbname=/, "").gsub(/\s/, "") : ''
			host = /host=.+?\s(?=)/.match(value).length != nil ? /host=.+?\s(?=)/.match(value)[0].gsub(/host=/, "").gsub(/\s/, "") : ''
			puts "Using the following parameters fetched from heroku toolbelt:
			-------------------------------------------
			host: #{host}
			username: #{username}
			password: #{password}
			database: #{database}
			-------------------------------------------"
		rescue
			# catches any exceptions from the automated method.
			puts "Could not execute command '$ #{cmd}"
			puts "Make sure heroku toolbelt is installed and you are logged into heroku."
			puts "Also be sure that the script is running from '/db/scripts/'"
			puts "Input the database:"
			database = gets
			puts "Input the host:"
			host = gets
			puts "Input the database username: (in root directory, run '$ heroku pg:credentials DATABASE')"
			username = gets
			puts "Input the database password:"
			password = gets
		end

		# connect to database,
		# run heroku pg:credentials in root to get info
		ActiveRecord::Base.establish_connection(
			:adapter => 'postgresql',
			:host => host,
			:username => username,
			:password => password,
			:database => database
		)
		puts "Connection to #{database} Established"
	end
	def testPath(path, restMethod, options = {})
		response = RestClient.method(restMethod).call path, options
		puts response
	end

	# string path, symbol method, regex for link, hash of options to pass to REST
	def getLinks(path, restMethod, linkRegex, options = {})
		# fetch base URL and get all links that match the regex
		response = RestClient.method(restMethod).call path, options
		# scan returns an array of all matched groups.
		urls = response.scan(linkRegex).map { |arr| arr.join "" }
		puts "#{path}."
		urls.each { |link| @urls << CGI::unescapeHTML(link) }
	end

	# pass a hash with each primary key and its regex for finding it on the page or its value
	def scrapeLinks!(obj, primary_keys = {}, options = {:sanitize=>[]})
		# remove duplicate links
		@urls = @urls.uniq
		insertions = []
		while(@urls.length>0)
			url = @urls.pop(1)[0] # fetches and deletes last element
			page = RestClient.get url
			page.gsub! "\\", "" # cleans up double nested json escape characters
			objHash = {}
			primary_keys.each do |key, val|
				if (val.is_a? Regexp) # if regex is passed, evaluate
					objHash[key] = page[val]
				elsif val == :site # if symbol :site is pased, return url
					objHash[key] = url
				else # otherwise, return value in the passed hash
					objHash[key] = val
				end

				# sanitize if in the sanitize key list
				if options[:sanitize].index(key)
					objHash[key] = HTMLEntities.new.decode(Sanitize.fragment objHash[key])
				end

			# TROUBLESHOOTER return any nil values from scraping
			objHash.each do |key, val|
				(p "WARNING: #{key} is: #{val} FOR URL:#{url}" if not val) # if val is nil
			end
			insertions << obj.new(objHash)
			sleep @sleep_time # to prevent ip blocking
		end

		obj.import insertions	# adds new ActiveRecord objects to database
	end
end
