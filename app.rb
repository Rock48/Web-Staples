require 'certified'
require 'sinatra'
require 'open-uri'
require 'open_uri_redirections'

set :bind, '0.0.0.0'
set :views, Proc.new { File.join(root, 'public') }

get '/' do
    #@time = open('http://tv.csapp.westport.k12.ct.us/api/time/now', :allow_redirections => :safe).read
    erb :index
end