#!/usr/bin/env sh

################################################################################
# Shell script to update permissions on BEdita3
# Shell user and web server have rwx permissions on backend and frontends tmp/i
# It must be invoked on BEdita instance root folder (where bedita-app/ and frontends/ are)
################################################################################

HTTPDUSER=`ps aux | grep -E '[a]pache|[h]ttpd|[_]www|[w]ww-data|[n]ginx' | grep -v root | head -1 | cut -d\  -f1`
BEGROUP=bedita

groupname=$1
if [[ -n "$groupname" ]]; then
    BEGROUP=$groupname
fi

if [ -z "$HTTPDUSER" ]; then
    echo "Web server user not found, verify that a webserver service (like Apache2) is up & running"
    exit 1;
fi

echo "Web server user is: $HTTPDUSER"
echo ""

echo ""
echo "Setting permissions on core /tmp and /files"
echo ""

for f in bedita-app/tmp bedita-app/webroot/files
do
        echo "permissions on $f"
        echo "chown -R :${BEGROUP} ${f}"
        chown -R :${BEGROUP} ${f}
        echo "chmod -R g+w ${f}"
        chmod -R g+w ${f}
        echo "setfacl -R -m u:${HTTPDUSER}:rwx ${f}"
        setfacl -R -m u:${HTTPDUSER}:rwx ${f}
        echo "setfacl -R -d -m u:${HTTPDUSER}:rwx ${f}"
        setfacl -R -d -m u:${HTTPDUSER}:rwx  ${f}
done

echo ""
echo "Setting permissions on frontends /tmp"
echo ""

for f in `ls -d frontends/*/`
do
        echo "permissions on $f"
        echo "chown -R :${BEGROUP} ${f}tmp"
        chown -R :${BEGROUP} ${f}tmp
        echo "chmod -R g+w ${f}tmp"
        chmod -R g+w ${f}tmp
        echo "setfacl -R -m u:${HTTPDUSER}:rwx ${f}tmp"
        setfacl -R -m u:${HTTPDUSER}:rwx ${f}tmp
        echo "setfacl -R -d -m u:${HTTPDUSER}:rwx ${f}tmp"
        setfacl -R -d -m u:${HTTPDUSER}:rwx  ${f}tmp
done
