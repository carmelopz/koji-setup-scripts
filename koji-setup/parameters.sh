export COUNTRY_CODE=US
export STATE=Oregon
export LOCATION=Hillsboro
export ORGANIZATION='Example org'
export ORG_UNIT='Example unit'
export KOJI_MASTER_FQDN=$(hostname -f)
export KOJI_SLAVE_FQDN="$KOJI_MASTER_FQDN"
export KOJI_DIR=/srv/koji
export CGIT_FQDN="$KOJI_MASTER_FQDN"
export EXTERNAL_REPO=https://cdn.download.clearlinux.org/releases/"$(curl https://download.clearlinux.org/latest)"/clear/\$arch/os/
export TAG_NAME=clear
export KOJID_CAPACITY=16
