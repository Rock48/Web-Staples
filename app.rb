require 'sinatra'
require 'open-uri'
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

set :bind, '0.0.0.0'
set :views, Proc.new { File.join(root, 'public') }

get '/' do
    @time = open('https://tv.csapp.westport.k12.ct.us/api/time/now').read
    @announcements = open('https://tv.csapp.westport.k12.ct.us/api/announcement/today').read
    erb :index
end