get '/api/time' do
  begin
    # use school time server
    return open('https://tv.csapp.westport.k12.ct.us/api/time/now', :ssl_ca_cert => CRT_FILE).read
  rescue
    # if something goes wrong return a timeout error
    return JSON.generate({
                             :code => ERROR_CODE_TIMEOUT,
                             :code_str => 'ERROR_CODE_TIMEOUT'
                         })
  end
end

# Get today's school announcements
get '/api/announcements/today' do
  begin
    # use schools api for announcements
    return open('https://tv.csapp.westport.k12.ct.us/api/announcement/today', :ssl_ca_cert => CRT_FILE).read
  rescue
    # if something goes wrong return a timeout error
    return JSON.generate({
                             :code => ERROR_CODE_TIMEOUT,
                             :code_str => 'ERROR_CODE_TIMEOUT'
                         })
  end
end

# Get today's school schedule
get '/api/schedule' do
  begin
    if params[:date] == 'today'
      # get the school's api for schedule
      return open('https://tv.csapp.westport.k12.ct.us/api/schedule/today', :ssl_ca_cert => CRT_FILE).read
    end
    # regex broke todo
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

# Get a user's schedule
get '/api/user/schedule' do
  if params[:authkey]
    # get the user who's profile is linked with given authkey's schedule
    begin
      schedule = DB[:schedules].where(:uid => DB[:authkeys].where(:key => sha512("#{params[:authkey]}#{AUTH_KEY}")).first[:uid]).first
    rescue
      # if fails return database error
      return JSON.generate({
                               :code => ERROR_DATABASE,
                               :code_str => 'Invalid (or expired) Auth Key or Database error (Try auth/login again) or database error'
                           })
    end
    # if all succeeds then return a success code
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
    # Authkey is required to get a users schedule
    return JSON.generate({
                             :code => ERROR_CODE_NO_AUTH,
                             :code_str => 'ERROR_CODE_NO_AUTH'
                         })
  end
end

# Updates a user's schedule
post '/api/user/schedule/update' do
  begin
    # attempt to retrieve the current users schedule with the authkey given
    usr_sched = DB[:schedules].where(:uid => DB[:authkeys].where(:key => sha512(params[:authkey] + AUTH_KEY)).first[:uid])
  rescue
    # if fails return database error
    return JSON.generate({
                             :code => ERROR_DATABASE,
                             :code_str => 'Invalid (or expired) Auth Key or Database error (Try auth/login again) or database error'
                         })
  end

  # Update the user's schedule with new information
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

  # Return success
  return JSON.generate({
                           :code => CODE_SUCCESS,
                           :code_str => 'Success',
                           :new_sched => usr_sched
                       })
end

# Register a new user
post '/api/user/new' do
  # Makes sure all parameters were passed
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

  # Makes sure all parameters have data in them
  if params[:email] == '' || params[:lname] == '' || params[:fname] == '' || params[:paswd] == ''
    return JSON.generate({
                             :code => ERROR_CODE_INVALID_DATA,
                             :code_str => 'DATA_BLANK'
                         })
  end

  # makes sure a valid email address was used
  if email_valid?(params[:email])
    return JSON.generate({
                             :code => ERROR_CODE_INVALID_DATA,
                             :code_str => 'DATA_EMAIL_INVALID',
                             :info => "#{params[:email]} did not match regexp #{VALID_EMAIL_REGEX.to_s}."
                         })
  end

  # makes sure account with passed email doesn't already exist
  unless DB[:users].where(:email => params[:email]).empty?
    return JSON.generate({
                             :code => ERROR_USER_EXISTS,
                             :code_str => 'ERROR_USER_EXISTS'
                         })
  end

  # generates a random string for a salt
  salt = rand_str(128)

  # combines password with the salt the salt as well as of random characters and the users email address in order to generate a secure hashed password
  pswd_salt_hash = sha512("#{params[:paswd]}A9ms*n1sz&b5#{params[:email]}11msa9;kSh&#n#{salt}")

  begin
    # attempts to insert a new user into the database
    id = DB[:users].insert(
        :email => params[:email],
        :paswd => pswd_salt_hash,
        :salt => salt,
        :fname => params[:fname],
        :lname => params[:lname]
    )

    # if user insertion succeeds then insert a new row into the user schedules table
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
    # if something goes wrong, returns a database error
    return JSON.generate({
                             :code => ERROR_DATABASE,
                             :code_str => 'ERROR_DATABASE',
                             :err => e.message
                         })
  end

  # Returns a success code indicating the user has been successfully registered.
  return JSON.generate({
                           :code => CODE_SUCCESS,
                           :code_str => 'Success'
                       })
end

# Deauthorize a given authkey
post '/api/user/deauth' do
  # makes sure authkey was passed
  unless params[:authkey]
    return JSON.generate({
                             :code => ERROR_AUTH_FAILED,
                             :code_str => 'Lol what are you thinking? You need something to de-auth'
                         })
  end

  begin
    # attemts to de-authorize the given authkey
    DB[:authkeys].where(:key => params[:authkey]).delete
  rescue
    # if given authkey isn't found (or database error) then return a database error
    return JSON.generate({
                             :code => ERROR_DATABASE,
                             :code_str => 'Invalid auth key or already de-authed or database error'
                         })
  end

  # returns success code
  return JSON.generate({
                           :code => CODE_SUCCESS,
                           :code_str => 'De-Authorization of auth key ' + params[:authkey] + ' successful'
                       })
end

# Generate an authkey for the user with the given email and password
post '/api/user/auth' do
  # makes sure an email and password was actually passed
  if params[:email] == '' || params[:paswd] == ''
    return JSON.generate({
                             :code => ERROR_CODE_INVALID_DATA,
                             :code_str => 'DATA_BLANK'
                         })
  end

  # searches the database for a user with the provided email address
  user_dataset = DB[:users].where(:email=>params[:email])

  # if the email address is not linked with any users, then return with a failed login
  if user_dataset.empty?
    return JSON.generate({
                             :code => ERROR_AUTH_FAILED,
                             :code_str => 'ERROR_AUTH_FAILED'
                         })
  end

  # gets the first user it finds in the database
  user = user_dataset.first

  # gets the random salt string generated when user created their account
  salt = user[:salt]

  # combines password with the salt the salt as well as of random characters and the users email address in order to generate a secure hashed password
  pswd_salt_hash = sha512("#{params[:paswd]}A9ms*n1sz&b5#{params[:email]}11msa9;kSh&#n#{salt}")

  # if the salted and hashed password doens't match what's in the database, then return with a failed login
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

  # inserts the authentication key into the database with all the verified authentication keys
  DB[:authkeys].insert(:key => auth_secure, :uid => user[:id])

  # returns authentication key for somebody to use
  return JSON.generate({
                           :code => CODE_SUCCESS,
                           :code_str => 'Authentication Successful. Keep your authkey secret',
                           :authkey => authkey
                       })
end

get '/api/user/profile' do
  if params[:authkey]
    begin
      # gets user id from database, then gets user information
      uid = DB[:authkeys].where(:key => sha512(params[:authkey] + AUTH_KEY)).first[:uid]
      user = DB[:users].where(:id => uid).first

        # catch errors and return them to the program using api: prevents unhandled errors
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

    # makes sure authkey returned a user id
    unless uid
      return JSON.generate({
                               :code => ERROR_AUTH_FAILED,
                               :code_str => 'AuthKey expired or non-existent'
                           })
    end

    # returns the user's profile (first name, last name, etc)
    return JSON.generate({
                             :code => CODE_SUCCESS,
                             :email => user[:email],
                             :fname => user[:fname],
                             :lname => user[:lname]
                         })
  end

  # you need to auth a user to get said users information
  return JSON.generate({
                           :code => ERROR_AUTH_FAILED,
                           :code_str => 'AUTHENTICATION REQUIRED'
                       })
end

# This was going to be a thing but ran out of time TODO
# # Lunch Schedule
# LUNCH_14_15 = [
#     [
#         [2],[3],[2],[3],[3],[1],[3],[3],[1],[2],[2],[1],[2],[1] # January
#     ],
#     [
#         [1],[3],[1],[3],[2],[3],[3],[3],[3],[1],[1],[3],[2],[2] # February
#     ],
#     [
#         [1],[3],[1],[3],[2],[3],[3],[3],[3],[1],[1],[3],[2],[2] # March
#     ],
#     [
#         [2],[3],[2],[3],[1],[3],[3],[3],[1],[2],[2],[3],[3],[3] # April
#     ],
#     [
#         [2],[3],[2],[3],[1],[3],[3],[3],[1],[2],[2],[3],[3],[3] # May
#     ],
#     [
#         [2],[3],[2],[3],[1],[3],[3],[3],[1],[2],[2],[3],[3],[3] # June
#     ]
# ]
#
# get '/api/schedule/lunch' do
#   begin
#     subject = params[:subject].to_i
#     month = params[:month].to_i
#   rescue StandardError => e
#     return JSON.generate({
#                              :code => ERROR_CODE_INVALID_DATA,
#                              :code_str => 'ERROR_CODE_INVALID_DATA',
#                              :exception => e
#                          })
#   end
#
# end

# TODO: homework / notes

# Public auth key
get '/api/user/auth/public' do
  return AUTH_KEY
end
