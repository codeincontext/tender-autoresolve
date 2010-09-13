require 'rubygems'
require 'json'
require 'active_support'
require 'net/http'

CFG = YAML.load_file("config.yml")
@http = Net::HTTP.new(CFG['api_url'])

def resolve(url)
  url.gsub!(/http:\/\/#{CFG['api_url']}/, '')
  
  request = Net::HTTP::Post.new(url, CFG['headers'])
  request.set_form_data(CFG['form_data'])
  response = @http.request(request)
  puts "#{response.code} - #{url}"
end

def scan_discussion(discussion)
  false
  if Time.parse(discussion['last_updated_at']) < CFG['time_period'].to_i.days.ago
    if CFG['quiet_resolve']
      resolve discussion['resolve_href']
    else
      resolve discussion['comments_href']
    end
    true
  end
end

def scan_page(state, page)
  request = Net::HTTP::Get.new("/#{CFG['project_path']}/discussions/#{state}?page=#{page}", CFG['headers'])
  response = @http.request(request)
	parsed = JSON::parse response.body

  continue = false
	parsed['discussions'].reverse.each do |discussion|
    continue = scan_discussion discussion
    break unless continue
	end
	continue
end

def scan_state(state)
  puts "State: #{state}"
  request = Net::HTTP::Get.new("/#{CFG['project_path']}/discussions/#{state}", CFG['headers'])
  response = @http.request(request)
  parsed = JSON::parse response.body

  per_page = parsed['per_page']
  pages = (parsed['total'] / per_page) + 1

  # Scan all pages until the discussions are newer than the time period
  pages.downto(1) do |page|
    break unless scan_page state, page
  end
end


CFG['states'].each do |state|
  scan_state state
end