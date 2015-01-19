require 'json'
require 'csv'
require 'net/smtp'

############ why? #############
###############################
## Reads CSV stream of local users with header in
## schema below from stdin with semicolon separator
## and adds creates a local user via RBAC API. Then
## pulls all users to acquire the SID (subject id) of
## the newly-added users which is needed to make an
## API request for a change password token. Token is
## requested and an email composed with the token in
## the proper URL format needed and sent to the new
## user. Initially tested by sending email to
## root@localhost. Comment line 99 to use user's email.
##
## CSV SCHEMA (I used semicolons instead of commas,
## because commas are needed in array of role IDs
## that the new user will belong to):
##
## login;email;display_name;role_ids 

############ settings #########
###############################
@console_server_name   = "localhost"
@smtp_server_name      = "localhost"
@mail_from             = "root@#{@console_server_name}"
@mail_subject          = "Please set your password for the Puppet Enterprise Console"

############ helpers ##########
###############################
$puppet = '/opt/puppet/bin/puppet'
credentials = {
  :cacert => %x(#{$puppet} config print localcacert),
  :cert   => %x(#{$puppet} config print hostcert),
  :key    => %x(#{$puppet} config print hostprivkey)
}

def rbac_rest_call (method, endpoint, creds, json="", api_ver="v1", console_server=@console_server_name)
  cmd = "curl -s -k -X #{method} -H 'Content-Type: application/json' \
    -d \'#{json}\' \
    --cacert #{creds[:cacert]} \
    --cert   #{creds[:cert]} \
    --key    #{creds[:key]} \
    https://#{console_server}:4433/rbac-api/#{api_ver}/#{endpoint}".delete("\n")
  resp = %x(#{cmd})
  ## don't know if api call succeeded, only if curl worked or not
  if ! $?.success?
    raise "curl rest call failed: #{$?}"
  end
  resp
end

############ data #############
###############################
## thanks to http://technicalpickles.com/posts/parsing-csv-with-ruby/ ##
## for ideas ##
CSV::Converters[:blank_to_nil] = lambda do |field|
  field && field.empty? ? nil : field
end

CSV::Converters[:array_parse] = lambda do |field|
  ## look for a string that looks like an array of integers (whitespace ok)
  if field.match(/^\s*\[\s*\d+\s*(\s*\,\s*\d+)*\s*\]\s*$/).nil?
    field
  else
    field.tr("[", "").tr("]", "").split(",").map { |s| s.to_i } 
  end
end

## reads csv stream from stdin with semicolon separator
csv = CSV.new(ARGF,
  :headers           => true,
  :col_sep           => ";",
  :skip_blanks       => true,
  :header_converters => :symbol,
  :converters        => [:all, :blank_to_nil, :array_parse])

users_arr  =  csv.to_a.map {|row| row.to_hash }
users_hash = {}
############ action ###########
###############################
users_arr.each do |user|
  rbac_rest_call("POST", "users", credentials, JSON.generate(user).to_s, "v1")
  users_hash[user[:login]] = user
end

response = rbac_rest_call("GET", "users", credentials)

JSON.parse(response).each do |record|
  l = users_hash[record["login"]]
  unless l.nil?
    id    = record["id"]
    token = rbac_rest_call("POST", "users/#{id}/password/reset", credentials,"","v1")
    url       =  "https://#{@console_server_name}/auth/reset?token=#{token}"
    mail_to   = record["email"]
    ## next line for testing & should be commented out to use user's email 
    mail_to   = "root@#{@smtp_server_name}"
    mail_date = %x(/bin/date -R)
    user_name = record["display_name"]

message = <<MESSAGE_END
From: Puppet Admin <#{@mail_from}>
To: #{user_name} <#{mail_to}>
Date: #{mail_date} 
Subject: #{@mail_subject}

Please vist the URL below to set your password:

login: #{record["login"]}
url: #{url}
MESSAGE_END

    Net::SMTP.start("#{@smtp_server}") do |smtp|
      smtp.send_message message, @mail_from, mail_to
    end
  end
end
