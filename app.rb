require 'sinatra'
require 'open-uri'
require 'json'

set :bind, '0.0.0.0'
set :views, Proc.new { File.join(root, 'public') }

CRT_FILE = File.join('C:', 'Ruby193', 'gd_bundle-g2.crt').to_s

get '/' do
    @time = open('https://tv.csapp.westport.k12.ct.us/api/time/now', :ssl_ca_cert => CRT_FILE).read
    @announcements = open('https://tv.csapp.westport.k12.ct.us/api/announcement/today', :ssl_ca_cert => CRT_FILE).read
    @schedule = open('https://tv.csapp.westport.k12.ct.us/api/schedule/today', :ssl_ca_cert => CRT_FILE).read

    @schedule_len = JSON.parse!(@schedule).length


    erb :index
end