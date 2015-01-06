
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
  if params[:authkey]
    schedule = DB[:schedules].where(:uid => DB[:authkeys].where(:key => sha512("#{params[:authkey]}#{AUTH_KEY}")).first[:uid]).first
    # noinspection RubyStringKeysInHashInspection
    return JSON.generate({
                             :code => CODE_SUCCESS,
                             '1' => schedule[:per1],
                             '2' => schedule[:per2],
                             '3' => schedule[:per3],
                             '4' => schedule[:per4],
                             '5' => schedule[:per5],
                             '6' => schedule[:per6],
                             '7' => schedule[:per7],
                             '8' => schedule[:per8]
                         })
  else
    return JSON.generate({
                             :code => ERROR_CODE_NO_AUTH,
                             :code_str => 'ERROR_CODE_NO_AUTH'
                         })
  end
end

post '/api/user/schedule/update' do
  begin
    usr_sched = DB[:schedules].where(:uid => DB[:authkeys].where(:key => sha512(params[:authkey] + AUTH_KEY)).first[:uid])
  rescue
    return JSON.generate({
                             :code => ERROR_DATABASE,
                             :code_str => 'Invalid Auth Key or Database error (Try auth/login again)'
                         })
  end
  usr_sched.update(
      :per1 => params[:per1],
      :per2 => params[:per2],
      :per3 => params[:per3],
      :per4 => params[:per4],
      :per5 => params[:per5],
      :per6 => params[:per6],
      :per7 => params[:per7],
      :per8 => params[:per8]
  )
  return JSON.generate({
                           :code => CODE_SUCCESS,
                           :code_str => 'Success',
                           :new_sched => usr_sched
                       })
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
  pswd_salt_hash = sha512("#{params[:paswd]}A9ms*n1sz&b5#{params[:email]}11msa9;kSh&#n#{salt}")

  begin
    id = DB[:users].insert(
        :email => params[:email],
        :paswd => pswd_salt_hash,
        :salt => salt,
        :fname => params[:fname],
        :lname => params[:lname]

    )
    DB[:schedules].insert(
        :uid => id,
        'per1' => '',
        'per2' => '',
        'per3' => '',
        'per4' => '',
        'per5' => '',
        'per6' => '',
        'per7' => '',
        'per8' => ''
    )
  rescue StandardError => e
    return JSON.generate({
                             :code => ERROR_DATABASE,
                             :code_str => 'ERROR_DATABASE',
                             :err => e.message
                         })
  end
  return JSON.generate({
                           :code => CODE_SUCCESS,
                           :code_str => 'Success'
                       })
end
# yee todo
post '/api/user/deauth' do
  unless params[:authkey]
    return JSON.generate({
                             :code => ERROR_AUTH_FAILED,
                             :code_str => 'Lol what are you thinking? You need something to de-auth'
                         })
  end
  begin
    DB[:authkeys].where(:key => params[:authkey]).delete
  rescue
    return JSON.generate({
                             :code => ERROR_DATABASE,
                             :code_str => 'Invalid auth key or already de-authed'
                         })
  end
  return JSON.generate({
                           :code => CODE_SUCCESS,
                           :code_str => 'De-Authorization of auth key ' + params[:authkey] + ' successful'
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
  pswd_salt_hash = sha512("#{params[:paswd]}A9ms*n1sz&b5#{params[:email]}11msa9;kSh&#n#{salt}")

  unless user[:paswd] == pswd_salt_hash
    return JSON.generate({
                             :code => ERROR_AUTH_FAILED,
                             :code_str => 'ERROR_AUTH_FAILED'
                         })
  end

  # Generate an authentication key !!!SECRET KEY!!!
  authkey = rand_str(64)

  # Hashes the auth key salted with the public one
  auth_secure = sha512(authkey + AUTH_KEY)

  DB[:authkeys].insert(:key => auth_secure, :uid => user[:id])

  return JSON.generate({
                           :code => CODE_SUCCESS,
                           :code_str => 'Authentication Successful. Keep your authkey secret',
                           :authkey => authkey
                       })
end

get '/api/user/profile' do
  if params[:authkey]
    begin
      uid = DB[:authkeys].where(:key => sha512(params[:authkey] + AUTH_KEY)).first[:uid]
      user = DB[:users].where(:id => uid).first
    rescue StandardError => e
      unless uid
        return JSON.generate({
                                 :code => ERROR_AUTH_FAILED,
                                 :code_str => 'AuthKey expired or non-existent'
                             })
      end
      return JSON.generate({
                               :code => ERROR_DATABASE,
                               :code_str => 'ERROR_DATABASE',
                               :exception => e
                           })
    end

    unless uid
      return JSON.generate({
                               :code => ERROR_AUTH_FAILED,
                               :code_str => 'AuthKey expired or non-existent'
                           })
    end

    return JSON.generate({
                             :code => CODE_SUCCESS,
                             :email => user[:email],
                             :fname => user[:fname],
                             :lname => user[:lname]
                         })
  end

  return JSON.generate({
                           :code => ERROR_AUTH_FAILED,
                           :code_str => 'AUTHENTICATION REQUIRED'
                       })
end

# Public auth key
get '/api/user/auth/public' do
  return AUTH_KEY
end