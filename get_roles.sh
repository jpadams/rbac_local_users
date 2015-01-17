# Run this script from the master
# /vagrant/scripts/setup_ds.sh
# to configure the sample DS.

PUPPET='/opt/puppet/bin/puppet'

curl -s -X GET -H 'Content-Type: application/json' \
--cacert `$PUPPET config print localcacert` \
--cert   `$PUPPET config print hostcert` \
--key    `$PUPPET config print hostprivkey` \
--insecure \
https://localhost:4433/rbac-api/v1/roles | python -m json.tool
