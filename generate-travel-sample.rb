# coding: utf-8
#
# This script generates sample data for `travel-sample` bucket.
#
# Dependencies:
# * redis and rubygem 'redis' to cache responses for geocoder APIs
# * rubygem geocoder to resolve country, city and state using geo coordinates 
#
# To install dependencies, use the following commands:
#
#   sudo yum install redis
#   gem install geocoder redis
#
# IMPORTANT NOTE: the script is using random generator to generate route
# tables, therefore the output might be different.

# Initialize random generator. Without any arguments to the script, it uses
# zero as seed.
srand(ARGV[0].to_i)

# This modification time will be assigned to all files in the archive
GLOBAL_MTIME = Time.utc(2015, 1, 1, 0, 0, 0)

start = Time.new
puts "== START: #{start}"
at_exit do
  finish = Time.now
  puts "== END: #{finish}"
  puts "== TOTAL: #{finish - start} seconds"
end

require 'rubygems'

begin
  gem 'redis'
rescue LoadError => ex
  abort "#{ex}.\nUse 'gem install redis' to install it"
end
require 'redis'
CACHE = Redis.new

begin
  gem 'geocoder'
rescue LoadError => ex
  abort "#{ex}.\nUse 'gem install geocoder' to install it"
end
require 'geocoder'
# https://github.com/alexreisner/geocoder#readme
# by default it is using yandex maps because it allows 25k requests
# per day, but for some landmarks it is necessary to switch to google,
# because they are missing on yandex maps
Geocoder.configure(cache: CACHE, timeout: 5, units: :km)

begin
  gem 'nokogiri'
rescue LoadError => ex
  abort "#{ex}.\nUse 'gem install nokogiri' to install it"
end
require 'nokogiri'

require 'csv'
require 'json'
require 'fileutils'
require 'English'
require 'byebug'
require 'digest/sha1'
require 'shellwords'

include FileUtils

def blank?(value)
  value.nil? || (value.is_a?(String) && value.strip.empty?)
end

def nullify_blank_keys(doc)
  doc.keys.each do |key|
    if doc[key].is_a?(Hash)
      nullify_blank_keys(doc[key])
    else
      doc[key] = nil if blank?(doc[key])
    end
  end
end

wikivoyage_url = 'https://ckannet-storage.commondatastorage.googleapis.com/2015-01-06T06:01:38.068Z/enwikivoyage-20141226-pages-articles-xml.csv'
wikivoyage_file = ARGV[0] || 'enwikivoyage-20141226-pages-articles-xml.csv'
unless File.exist?(wikivoyage_file)
  puts("downloading #{wikivoyage_url} to #{wikivoyage_file}...")
  system("curl -O#{wikivoyage_file} #{wikivoyage_url}")
end

print('Fixing XML double quotes where they conflict with CSV quotes... ')
fixed_lines = 0
temp_file = "#{wikivoyage_file}.tmp"
File.open(wikivoyage_file) do |input|
  File.open(temp_file, 'w+') do |output|
    loop do
      line = input.gets
      break unless line
      fixed = line.gsub(/=\s*"([^"]*)"/, "='\1'")
      fixed_lines += 1 if fixed != line
      output.puts(fixed)
    end
  end
end
if fixed_lines == 0
  rm(temp_file)
  puts('ok')
else
  mv(temp_file, wikivoyage_file)
  puts("fixed #{fixed_lines} lines")
end

rm_rf('travel/docs')
rm_rf('travel-sample/docs')
puts("converting #{wikivoyage_file} to JSON files into travel/docs/...")
mkdir_p('travel/docs')
mkdir_p('travel-sample/docs')
csv = CSV.open(wikivoyage_file, headers: true, col_sep: ';', header_converters: :downcase)
idx = 0
missing_on_yandex_maps = [
  9034, 15484, 15485, 15486, 17360, 17361, 17362, 17363,
  17364, 17365, 17366, 17367, 17368, 17369, 40385
]
swapped_coordinates = [
  634, 3495, 33129
]
chosen_countries = ['United States', 'France', 'United Kingdom']
csv.each do |row|
  Geocoder.configure(lookup: :yandex)
  key = "landmark_#{idx}"
  doc = row.to_h
  lat = doc.delete('lat').to_f
  lon = doc.delete('lon').to_f
  next if lat == 0 || lon == 0 || blank?(doc['name']) || blank?(doc['content'])
  doc['geo'] = {lat: lat, lon: lon}
  doc['activity'] = doc.delete('type')
  doc['type'] = 'landmark'
  doc['id'] = idx
  if swapped_coordinates.include?(doc['id'])
    doc['geo'] = {lat: lon, lon: lat}
  end
  if missing_on_yandex_maps.include?(doc['id'])
    Geocoder.configure(lookup: :google)
  end
  geo = Geocoder.search(doc['geo'].values_at(:lat, :lon).join(','))
  if geo && geo = geo.first
    doc['country'] = geo.country
    doc['country'] = 'United Kingdom' if doc['country'] =~ /^United Kingdom/
    doc['city'] = geo.city
    doc['state'] = geo.state
  else
    puts "\n#{doc['geo'].values_at(:lat, :lon).join(',')}\t#{doc['id']}\n"
  end
  nullify_blank_keys(doc)
  unless blank?(doc['image'])
    doc['image'] = "https://en.wikivoyage.org/wiki/File:#{doc['image']}"
    cache_key = "image:#{Digest::SHA1.hexdigest(doc['image'])}"
    if url = CACHE.get(cache_key)
      doc['image_direct_url'] = url
    else
      # try to resolve original image
      begin
        html = Nokogiri::HTML(`curl -sL #{doc['image'].shellescape}`)
        unless $CHILD_STATUS.success?
          puts "\nERROR: curl -sL #{doc['image'].shellescape}\n"
        end
        links = html.css('div.fullMedia a')
        doc['image_direct_url'] = "https:#{links.first['href']}" if links && links.first
        CACHE.set(cache_key, doc['image_direct_url'])
      rescue => ex
        abort "#{doc['image']}: #{ex}"
      end
    end
  end
  File.write("travel/docs/#{key}.json", doc.to_json)
  if doc['country'] == 'United Kingdom' || doc['country'] == 'France' ||
     (doc['country'] == 'United States' && doc['state'] == 'California')
    File.write("travel-sample/docs/#{key}.json", doc.to_json)
  end
  print("\r#{key}.json")
  STDOUT.flush
  idx += 1
end
puts

air_url = 'https://github.com/ToddGreenstein/try-cb-nodejs/raw/1c6bea3f1ae56a4ad54d096c02e7c86e7f5632f8/model/raw/rawJsonAir.js'
air_file = 'rawJsonAir.js'
unless File.exist?(air_file)
  puts("downloading #{air_url} to #{air_file}...")
  system("curl -L -O#{air_file} #{air_url}")
end

puts("extracting airline data from #{air_file}... ")
def random_schedule(airline)
  schedule = []
  # adds a schedule entry for at least every day
  7.times do |day|
    rand(1..5).times do
      schedule.push(
        day: day,
        utc: format('%02d:%02d:00', rand(0..23), rand(0..59)),
        flight: format('%s%d%d%d', airline, rand(0..9), rand(0..9), rand(0..9))
      )
    end
  end
  schedule
end

old_sep, $INPUT_RECORD_SEPARATOR = $INPUT_RECORD_SEPARATOR, "\r"
prev_type = nil
inactive_airlines = []
chosen_airlines = []
chosen_airports = []
airports = {}
File.open(air_file) do |input|
  loop do
    line = input.gets
    break unless line
    next unless line[0] == '{'
    line = line.sub(/"Peau Vava.*"/, '"Peau Vavaʻu"')
    doc = JSON.load(line.sub(/[\r,]*$/, ''))
    active = doc.delete('active')
    doc['id'] = doc['id'].to_i
    key = "#{doc['type']}_#{doc['id']}"
    if doc.key?('icao') && (blank?(doc['icao']) || doc['icao'] == 'N' || doc['icao'] == '...')
      doc['icao'] = nil
    end
    if active == 'N' || doc['id'] == 18860 ||
       ( # skip airports or airlines without sensible codes
         (doc.key?('faa') || doc.key?('icao')) &&
         blank?(doc['faa']) && blank?(doc['icao'])
       )
      inactive_airlines << key
      next
    end
    doc['stops'] = doc['stops'].to_i if doc.key?('stops')
    # doc['name'] = doc.delete('airportname') if doc.key?('airportname')
    geo = doc.delete('geo')
    if geo
      doc['geo'] = {
        lat: geo['latitude'].to_f,
        lon: geo['longitude'].to_f,
        alt: geo['altitude'].to_f
      }
      next if doc['geo'][:lat] == 0 || doc['geo'][:lon] == 0
    end
    doc.delete('keywords')
    doc.delete('gmtoffset')
    doc.delete('dst')
    prev_type ||= doc['type']
    doc['schedule'] = random_schedule(doc['airline']) if doc['type'] == 'route'
    nullify_blank_keys(doc)
    if doc['type'] == 'airport'
      airports[doc['faa']] = doc
      airports[doc['icao']] = doc
    end
    File.write("travel/docs/#{key}.json", doc.to_json)
    if chosen_countries.include?(doc['country']) || doc['type'] == 'route'
      File.write("travel-sample/docs/#{key}.json", doc.to_json)
      chosen_airlines << key if doc['type'] == 'airline'
      chosen_airports << doc['icao'] << doc['faa'] if doc['type'] == 'airport'
    end
    if prev_type != doc['type']
      prev_type = doc['type']
      puts
    end
    print("       \r#{key}.json")
    STDOUT.flush
  end
end
$INPUT_RECORD_SEPARATOR = old_sep
puts

chosen_airports.compact!
airports.delete(nil)
unless inactive_airlines.empty?
  count = 0
  puts("removing routes from #{inactive_airlines.size} inactive airlines... ")
  Dir['travel-sample/docs/route_*.json'].sort_by { |name| name[/(\d+)/, 1].to_i }.each do |route_file|
    route = JSON.load(File.read(route_file))
    if inactive_airlines.include?(route['airlineid']) ||
       !airports.key?(route['sourceairport']) ||
       !airports.key?(route['destinationairport']) ||
       !(chosen_airlines.include?(route['airlineid']) ||
         chosen_airports.include?(route['sourceairport']) ||
         chosen_airports.include?(route['destinationairport']))
      rm_rf(route_file)
      print("        \r#{File.basename(route_file)}")
      STDOUT.flush
      count += 1
    else
      from = airports[route['sourceairport']]['geo']
      to = airports[route['destinationairport']]['geo']
      route[:distance] = Geocoder::Calculations.distance_between([from[:lat], from[:lon]],
                                                                 [to[:lat], to[:lon]])
      File.write(route_file, route.to_json)
    end
  end
  puts "\nremoved #{count} routes in reduced dataset"
  count = 0
  Dir['travel/docs/route_*.json'].sort_by { |name| name[/(\d+)/, 1].to_i }.each do |route_file|
    route = JSON.load(File.read(route_file))
    if inactive_airlines.include?(route['airlineid']) ||
       !airports.key?(route['sourceairport']) ||
       !airports.key?(route['destinationairport'])
      rm_rf(route_file)
      print("        \r#{File.basename(route_file)}")
      STDOUT.flush
      count += 1
    else
      from = airports[route['sourceairport']]['geo']
      to = airports[route['destinationairport']]['geo']
      route[:distance] = Geocoder::Calculations.distance_between([from[:lat], from[:lon]],
                                                                 [to[:lat], to[:lon]],
                                                                 units: :km)
      File.write(route_file, route.to_json)
    end
  end
  puts "\nremoved #{count} routes"
end

design_docs = {
  spatial:
    {
      _id: '_design/spatial',
      language: 'javascript',
      spatial: {
        poi: <<JS,
/*
  This function indexes airports and landmarks. An example app would
  show them on a map and you could click on them and get the name and
  URL if there is one. Or you could have a list of items in a table
  below the map that shows the items by name and the URL.
*/
function(doc, meta) {
    var activityToNumber = {
        'buy': 1,
        'do': 2,
        'drink': 3,
        'eat': 4,
        'listing': 5,
        'see': 6,
        'sleep': 7
    };

    var key;
    var value;
    if (doc.type === 'airport') {
        // We store airports as activity `0`
        key = [doc.geo.lon, doc.geo.lat, doc.geo.alt, 0];
        value = {name: doc.airportname};
        emit(key, value);
    }
    else if(doc.type === 'landmark') {
        key = [doc.geo.lon, doc.geo.lat, 0, activityToNumber[doc.activity]];
        value = {name: doc.name};
        if (doc.url !== null) {
            value.url = doc.url;
        }
        emit(key, value);
    }
}
JS
        routes: <<JS
/*
  Emit all the flights. You can filter them by day and time.
*/
function(doc, meta) {
    if (doc.type === 'route') {
        for (var i = 0; i < doc.schedule.length; i++) {
            var schedule = doc.schedule[i];
            var time = parseInt(schedule.utc.replace(/:/g, ''));
            var key = [schedule.day, time];
            var value = [
                schedule.flight,
                doc.sourceairport,
                doc.destinationairport
            ];
            emit(key, value);
        }
    }
}
JS
      }
    }
}

n1ql_indexes = {
  statements: [
    {
      statement: "CREATE PRIMARY INDEX def_primary on `travel-sample` USING GSI",
      args: nil
    },
    {
      statement: "CREATE INDEX def_name_type on `travel-sample`(name) WHERE _type='User' USING GSI",
      args: nil
    },
    {
      statement: "CREATE INDEX def_faa ON `travel-sample`(faa) USING GSI",
      args: nil
    },
    {
      statement: "CREATE INDEX def_icao ON `travel-sample`(icao) USING GSI",
      args: nil
    },
    {
      statement: "CREATE INDEX def_city ON `travel-sample`(city) USING GSI",
      args: nil
    },
    {
      statement: "CREATE INDEX def_airportname ON `travel-sample`(airportname) USING GSI",
      args: nil
    },
    {
      statement: "CREATE INDEX def_type ON `travel-sample`(type) USING GSI",
      args: nil
    },
    {
      statement: "CREATE INDEX def_sourceairport ON `travel-sample`(sourceairport) USING GSI",
      args: nil
    },
    {
      statement: "BUILD INDEX ON `travel-sample`(def_primary,def_name_type,def_faa,def_icao,def_city,def_airportname,def_type,def_sourceairport) USING GSI",
      args: nil
    }
  ]
}

%w(travel travel-sample).each do |dir|
  FileUtils.mkdir_p("#{dir}/design_docs")
  design_docs.each do |name, contents|
    File.write("#{dir}/design_docs/#{name}.json", contents.to_json)
  end
  File.write("#{dir}/design_docs/indexes.json", n1ql_indexes.to_json)
end

%w(travel travel-sample).each do |dir|
  rm("#{dir}.zip") if File.exist?("#{dir}.zip")
  puts("set mtime of all files to #{GLOBAL_MTIME}...")
  Dir["**/*"]
    .sort_by { |f| [File.directory?(f) ? 1 : 0, f] }
    .map { |f| FileUtils.touch(f, mtime: GLOBAL_MTIME) }
  puts("archiving to #{dir}.zip...")
  system("zip -9rqX #{dir}.zip #{dir}")
  rm_rf(dir)
end
