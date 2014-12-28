require 'sinatra'
require 'open-uri'
require 'json'
require 'sequel'
require 'digest'

set :bind, '0.0.0.0'
set :views, Proc.new { File.join(root, 'public') }
enable :sessions

VALID_EMAIL_REGEX = /\A([\w+\-].?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i

def email_valid?(email)
  email =~ VALID_EMAIL_REGEX
end

#BEGIN RETURN CODE DEFINITIONS

CODE_SUCCESS = 0

#Errors
ERROR_CODE_NO_AUTH = 100
ERROR_CODE_TIMEOUT = 101
ERROR_CODE_INVALID_DATE = 102
ERROR_CODE_INVALID_DATA = 103
ERROR_USER_EXISTS = 104
ERROR_DATABASE = 105
ERROR_AUTH_FAILED = 106

#END RETURN CODE DEFINITIONS

CRT_FILE = File.join('C:', 'Ruby193', 'gd_bundle-g2.crt').to_s

DB = Sequel.connect('sqlite://webstaples.db')

def rand_str(length)
  (36**(length-1) + rand(36**length)).to_s(36)
end

get '/' do
    # noinspection RubyArgCount
    @schedule_len = JSON.parse!(open('http://localhost:4567/api/schedule?date=today').read).length
    puts @schedule_len
    erb :index
end

get '/api/time' do
    begin
        return open('https://tv.csapp.westport.k12.ct.us/api/time/now', :ssl_ca_cert => CRT_FILE).read
    rescue
        return JSON.generate({
                                 :code => ERROR_CODE_TIMEOUT,
                                 :code_str => 'ERROR_CODE_TIMEOUT'
                             })
    end
end

get '/api/announcements/today' do
    begin
        open('https://tv.csapp.westport.k12.ct.us/api/announcement/today', :ssl_ca_cert => CRT_FILE).read
    rescue
        return JSON.generate({
                             :code => ERROR_CODE_TIMEOUT,
                             :code_str => 'ERROR_CODE_TIMEOUT'
                         })
    end
end

get '/api/schedule' do
    begin

        if params[:date] == 'today'
            return open('https://tv.csapp.westport.k12.ct.us/api/schedule/today', :ssl_ca_cert => CRT_FILE).read
        end
        date = params[:date].match(/\b[1-3][0-9]{3}-([1][0-2]|[1-9])-([1-2][0-9]|3[0-1]|[1-9])\b/)
        if date
            date_split = params[:date].split('-')

            return open("https://tv.csapp.westport.k12.ct.us/api/schedule/#{date_split[0]}/#{date_split[1]}/#{date_split[2]}", :ssl_ca_cert => CRT_FILE).read
        else
            return JSON.generate({
                                     :code => ERROR_CODE_TIMEOUT,
                                     :code_str => 'ERROR_CODE_TIMEOUT'
                                 })
        end
    rescue
        return JSON.generate({
                             :code => ERROR_CODE_INVALID_DATE,
                             :code_str => 'ERROR_CODE_INVALID_DATE'
                         })
    end
end

get '/api/user/schedule' do
    if session[:usrSched]
      return JSON.generate(session[:usrSched]);
    else
      return JSON.generate({
                                :code => ERROR_CODE_NO_AUTH,
                                :code_str => 'ERROR_CODE_NO_AUTH'
                           })
    end
end

post '/' do #TODO: User logins w/ databases instead of just cookies
    if params[:config_per] == 'Apply'
        session[:usrSched] = {
          :code => CODE_SUCCESS,
          '1' => params[:per1],
          '2' => params[:per2],
          '3' => params[:per3],
          '4' => params[:per4],
          '5' => params[:per5],
          '6' => params[:per6],
          '7' => params[:per7],
          '8' => params[:per8]
        }
        redirect('/')
    end
    if params[:register] == 'Submit'
      response = Net::HTTP.post_form('http://localhost:4567/api/user/new', :email => params[:email], :paswd => params[:paswd], :fname => params[:fname], :lname => params[:lname])
    end
end

post '/api/user/new' do
   if params[:paswd] == nil
     return JSON.generate({
                              :code => ERROR_CODE_INVALID_DATA,
                              :code_str => 'DATA_PASWD_MISSING'
                          })
   end
   if params[:email] == nil
     return JSON.generate({
                              :code => ERROR_CODE_INVALID_DATA,
                              :code_str => 'DATA_EMAIL_MISSING'
                          })
   end
   if params[:fname] == nil
     return JSON.generate({
                              :code => ERROR_CODE_INVALID_DATA,
                              :code_str => 'DATA_FNAME_MISSING'
                          })
   end
   if params[:lname] == nil
     return JSON.generate({
                              :code => ERROR_CODE_INVALID_DATA,
                              :code_str => 'DATA_LNAME_MISSING'
                          })
   end
   if email_valid?(params[:email])
     return JSON.generate({
                              :code => ERROR_CODE_INVALID_DATA,
                              :code_str => 'DATA_EMAIL_INVALID',
                              :info => "#{params[:email]} did not match regexp #{VALID_EMAIL_REGEX.to_s}."
                          })
   end
   unless DB[:users].where(:email => params[:email]).empty?
     return JSON.generate({
                              :code => ERROR_USER_EXISTS,
                              :code_str => 'ERROR_USER_EXISTS'
                          })
   end

   salt = rand_str(128)
   pswd_salt_hash = Digest::SHA2.new(512).update(params[:passwd] + 'A9ms*n1sz&b5' + params[:email] + '11msa9;kSh&#n' + salt).to_s

   begin
     DB[:users].insert(
                   :email => params[:email],
                   :paswd => pswd_salt_hash,
                   :salt => salt,
                   :fname => params[:fname],
                   :lname => params[:lname]

     )
   rescue
    return JSON.generate({
                             :code => ERROR_DATABASE,
                             :code_str => 'ERROR_DATABASE'
                         })
   end
   return JSON.generate({
                            :code => CODE_SUCCESS,
                            :code_str => 'Success'
                        })
end
post '/api/user/auth' do
  user_dataset = DB[:users].where(:email=>params[:email])

  if user_dataset.empty?
    return JSON.generate({
                             :code => ERROR_AUTH_FAILED,
                             :code_str => 'ERROR_AUTH_FAILED'
                         })
  end
  user = user_dataset.first

  salt = user[:salt]
  pswd_salt_hash = Digest::SHA2.new(512).update(params[:passwd] + 'A9ms*n1sz&b5' + params[:email] + '11msa9;kSh&#n' + salt).to_s

  unless user[:paswd] == pswd_salt_hash
    return JSON.generate({
                             :code => ERROR_AUTH_FAILED,
                             :code_str => 'ERROR_AUTH_FAILED'
                         })
  end

  session[:logged_in] = true
  session[:u_email] = params[:email]
  session[:u_fname] = params[:fname]
  session[:u_lname] = params[:lname]
  session[:u_id] = user[:id]

end
get '/clearcookies' do
    session.clear
    session[:logged_in] |= false
    redirect('/')
end
