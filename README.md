# ruby-scraper
Ruby crawler and scraper for postgres or other SQL-based databases. Generates active record objects.

## General Usage:
1. Require or include the active record models. <br>
2. Create a new scraper object `obj = Scraper.new`. <br>
3. Use `Scraper.connectDatabase` to connect the remote heroku database.<br>
4. `obj.testPath "http://example.com", :get` will print the raw http request from the url. (In terminal, redirect the output of the file to a text file for easy regular expression analysis: `path $ ruby scraper.rb > output.txt`)<br>
5. Create a list of links: `obj.getLinks "http://example.com", :get, /urlRegex/`. The getLinks method takes a regex and whose matches should be the urls.<br>
6. Scrape each link and build an active record object: `obj.scrapeLinks! Job, {attributes_hash}, {:sanitize => [list of keys for attributes that should be html safe]}`. The attributes hash should be filled with each of the assigned attributes of the active record object with its corresponding regex to match it in the html request. The symbol `:site` if passed as a value with set the attribute to the current url.

### Crawlify Documentation
Create a new crawler object `my_crawler = Crawlify::Crawler.new("website")`

### `#crawl(resource_path, url)`
Crawls from a base path, retrieving all linked resources from a starting url. `resource_path` is the root directory that will be created in the output directory.

### `#save(resource_path, body)`
Saves a body of text to the resource path specified.

### configurations
configuration settings can be passed to a new crawler object.

`Crawlify::Crawler.new("website", stop: "myregex")` specify a pattern. If any web page matches the regular expression, the program will terminate rather than continuing to crawl.

`Crawlify::Crawler.new("website", doc_type: "xml")` to specify a different file type to crawl. Default is html

