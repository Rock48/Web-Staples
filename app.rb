require 'sinatra'
require 'open-uri'
require 'json'
require 'sequel'
require 'digest'
require 'net/http'

set :bind, '0.0.0.0'
set :views, Proc.new { File.join(root, 'public') }
enable :sessions

VALID_EMAIL_REGEX = /^[a-z 0-9 \- _]@[a-z 0-9].[a-z]/

def email_valid?(email)
  email =~ VALID_EMAIL_REGEX
end

#BEGIN RETURN CODE DEFINITIONS
CODE_SUCCESS = 0

#ERRORS
ERROR_CODE_NO_AUTH = 100
ERROR_CODE_TIMEOUT = 101
ERROR_CODE_INVALID_DATE = 102
ERROR_CODE_INVALID_DATA = 103
ERROR_USER_EXISTS = 104
ERROR_DATABASE = 105
ERROR_AUTH_FAILED = 106

#END RETURN CODE DEFINITIONS

#SUBJECTS
ACADEMIC_SUPPORT_CTR = 0
ART = 1
ENGLISH = 2
FAM_CUCUMBER_SCIENCES = 3 # Consumer
MATHEMATICS = 4
MEDIA = 5
MUSIC = 6
PYSHED = 7
SCIENCE = 8
SOCIAL_STUDIES = 9
SPECIAL_ED = 10
TECHNOLOGY = 11
THEATER = 12
WORLD_LANGUAGES = 13

# noinspection SpellCheckingInspection
AUTH_KEY = 'aka8H3DSafa98xq401s378alAiAGD6GApO2hjAHGijh3Hu2'

CRT_FILE = File.join('C:', 'Ruby200-x64', 'gd_bundle-g2.crt').to_s

DB = Sequel.connect('sqlite://webstaples.db')

# Generate a random string of given @param length
def rand_str(length)
  (36**(length-1) + rand(36**length)).to_s(36)
end

# Generate a sha512 hash with given string
def sha512(str)
  Digest::SHA2.new(512).update(str).to_s
end

# get the homepage
get '/' do
    # sets the logged in cookie to false if not yet set
    session[:loggedin] |= false

    # figure out the length of today's schedule
    # noinspection RubyArgCount
    @schedule_len = JSON.parse!(open('http://localhost:4567/api/schedule?date=today').read).length

    # check if user is logged it
    if session[:loggedin]
      # if so get the user's profile
      response = Net::HTTP.get(URI('http://localhost:4567/api/user/profile?authkey='+session[:authkey]))

      # parse the json into a ruby hash
      # noinspection RubyArgCount
      @profile = JSON.parse!(response)
    end

    # send index.erb
    erb :index
end

# send
post '/' do
    if params[:config_per] == 'Apply' and session[:loggedin]
      Net::HTTP.post_form(URI('http://localhost:4567/api/user/schedule/update'), :authkey => session[:authkey], :per1 => params[:per1], :per2 => params[:per2], :per3 => params[:per3], :per4 => params[:per4], :per5 => params[:per5], :per6 => params[:per6], :per7 => params[:per7], :per8 => params[:per8])
      redirect('/')
    end

    if params[:login] == 'Submit'
      response = Net::HTTP.post_form(URI('http://localhost:4567/api/user/auth'), :email => params[:email], :paswd => params[:paswd]).body

      # noinspection RubyArgCount
      res = JSON.parse!(response)

      if res['code'] == CODE_SUCCESS
        session[:authkey] = res['authkey']
        session[:loggedin] = true

        redirect('/')
      end

      if res['code'] == ERROR_AUTH_FAILED
        @schedule_len = JSON.parse!(open('http://localhost:4567/api/schedule?date=today').read).length
        @message = 'Invalid Email or Password'

        return erb :index
      end

      if res['code'] == ERROR_CODE_INVALID_DATA
        @schedule_len = JSON.parse!(open('http://localhost:4567/api/schedule?date=today').read).length
        @message = 'You must enter an email and a password'

        return erb :index
      end

      return res.inspect
    end
    if params[:register] == 'Submit'
      response = Net::HTTP.post_form(URI('http://localhost:4567/api/user/new'), :email => params[:email], :paswd => params[:paswd], :fname => params[:fname], :lname => params[:lname]).body

      # noinspection RubyArgCount
      res = JSON.parse!(response)

      if res['code'] == CODE_SUCCESS
        redirect('/')
      end
      if res['code'] == ERROR_CODE_INVALID_DATA
        @schedule_len = JSON.parse!(open('http://localhost:4567/api/schedule?date=today').read).length
        @message = '<i>ALL</i> Fields are required'

        return erb :index
      end

      return 'Error <br>' + response
    end
end

get '/cur_auth_sched' do
  if session[:loggedin]
    return Net::HTTP.get(URI('http://localhost:4567/api/user/schedule?authkey='+session[:authkey]))
  end

  return '{"1":"","2":"","3":"","4":"","5":"","6":"","7":"","8":"",code:1}'
end

get '/cur_usr_profile' do
  if session[:loggedin]
    return Net::HTTP.get(URI('http://localhost:4567/api/user/profile?authkey='+session[:authkey]))
  end

  return '{"fname": "Guest", "lname": "", "email": ""}'
end

get '/logout' do
    Net::HTTP.post_form(URI('http://localhost:4567/api/user/deauth'), :authkey => session[:authkey])

    session.clear
    session[:logged_in] |= false
    redirect('/')
end

require './api.rb'
