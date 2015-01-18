## Why?
This is an example of how you could use the PE RBAC
APIs to bulk add users from a CSV file and issue
emails with a one-time token for them to set
their own passwords.

This assumes being run from a bash prompt on server running console services (rbac service, nc service) and with certs on it. Basically, I tested it on a monolithic PE 3.7.1 Master. Should think about how to use this in split install.

The CSV file is semi-colon delimited. See the foo.csv example file. The header is required as is.

## Usage:

```
# cat foo.csv | /opt/puppet/bin/ruby add_users.rb
```

## To Do:

 - Mail stuff needs some looking at.

 - Make ready for split install. Need to get certs/keys wrangled ahead of time and made an argument or something.

