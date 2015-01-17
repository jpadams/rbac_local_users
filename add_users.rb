require 'json'
require 'csv'
require 'net/smtp'

############ helpers ##########
###############################
puppet = '/opt/puppet/bin/puppet'
credentials = {
  :cacert => %x(#{puppet} config print localcacert),
  :cert   => %x(#{puppet} config print hostcert),
  :key    => %x(#{puppet} config print hostprivkey)
}

def rbac_rest_call (method, endpoint, creds, json="", api_ver="v1")
  cmd = "curl -s -k -X #{method} -H 'Content-Type: application/json' \
    -d \'#{json}\' \
    --cacert #{creds[:cacert]} \
    --cert   #{creds[:cert]} \
    --key    #{creds[:key]} \
    https://localhost:4433/rbac-api/#{api_ver}/#{endpoint}".delete("\n")
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

master_name   = "master.inf.puppetlabs.demo"
mail_from     = "root@#{master_name}"

JSON.parse(response).each do |record|
  l = users_hash[record["login"]]
  unless l.nil?
    id    = record["id"]
    token = rbac_rest_call("POST", "users/#{id}/password/reset", credentials,"","v1")
    url       =  "https://#{master_name}/auth/reset?token=#{token}"
    mail_to   = record["email"]
    ## the next line is for testing only and should be commented out
    mail_to   = "root@#{master_name}"
    mail_date = %x(/bin/date -R)
    user_name = record["display_name"]

message = <<MESSAGE_END
From: Puppet Admin <#{mail_from}>
To: #{user_name} <#{mail_to}>
Date: #{mail_date} 
Subject: Please set your password for the Puppet Enterprise Console 

Please vist the URL below to set your password:

login: #{record["login"]}
url: #{url}
MESSAGE_END

    Net::SMTP.start('localhost') do |smtp|
      smtp.send_message message, mail_from, mail_to
    end
  end
end
