require 'glom/version'
require 'rubygems'
require 'net/http'
require 'json'
require 'tmpdir'

# Require individual registry logic
Dir["#{File.dirname __FILE__}/glom/registries/*.rb"].each do |file|
  require file
end

module Glom
  self.constants.each do |constant|
    constant = self.const_get constant
    (@@registries_all ||= []) << constant if constant.is_a? Module
  end
  
	def detect(query)
	  @query = query.dup
	 
	  @@registries_all.each do |registry|
	    registry::KEYWORDS.each do |keyword|
	      if query.include? keyword
	        (@registries ||= []) << registry
	        @query.slice! keyword
	        @query.strip!
	      end
	    end
	  end
	  
	  @registries = Glom::REGISTRIES unless defined? @registries
	end

	def search
	  @registries.each do |registry|
	    include registry
	    
	    puts "\nSearching `#{registry::URL}` for `#{@query}`...\n"
	    
	    (@packages ||= []).concat registry.standardize(@query)
	  end
	end
	
	def sort
	  @packages.sort_by! do |package|
	    -package[3]
	  end
	end
	
	def display
	  # Require terminal-table
	  require 'glom/terminal-table/cell.rb'
	  require 'glom/terminal-table/core_ext.rb'
	  require 'glom/terminal-table/row.rb'
	  require 'glom/terminal-table/separator.rb'
	  require 'glom/terminal-table/style.rb'
	  require 'glom/terminal-table/table_helper.rb'
	  require 'glom/terminal-table/table.rb'
	  require 'glom/terminal-table/version.rb'
    
	  table = Terminal::Table.new
	  table.headings = ['Name', 'Description', 'Author', 'Stars', 'Last Updated', 'Registry']
	  table.rows = @packages[0..20]
	  table.style = {
  	  :width => `/usr/bin/env tput cols`.to_i
	  }
	  
	  puts ""
	  puts table
	end
	
	def get(address)
	  cache = "#{Dir.tmpdir}/#{address.gsub(/[\x00\/\\:\*\?\"<>\|]/, '_').gsub('.json', '')}.json"
	  
	  if File.exist? cache
      json = IO.read(cache)
    else
  	  url = URI.parse(address)
  	  
      http = Net::HTTP.new(url.host, url.port)
      if address =~ /^https/
        http.use_ssl = true
        # http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      
      req = Net::HTTP::Get.new(url.request_uri)
      res = http.request(req)
      
      json = res.body
      
      output = File.new(cache, 'w')
      output.puts json
      output.close
    end
    
    return json
	end
end
