#!/bin/sh
set -exv

SSL_DH_FILE="/etc/nginx/ssl/dhparams.pem"
SSL_KEY="/etc/nginx/ssl/key.pem"
SSL_CERT="/etc/nginx/ssl/cert.pem"
VARS_COMMON="/etc/nginx/conf.d/vars_common"
GLOBAL_allow_IPs=/etc/nginx/conf.d/GLOBAL_allow_IPs
HTTPS_CONFIG="/etc/nginx/conf.d/SERVER_HTTPS_and_redirected_HTTP"
HTTP_CONFIG="/etc/nginx/conf.d/SERVER_HTTP_only"
MAINTENANCE="/etc/nginx/conf.d/SERVER_MAINTENANCE"
PID_CERT_CREATER="/etc/nginx/ssl/SSL_create.pid"
MAINTENANCE_HTML_PATH="/var/www/maintenance"
MAINTENANCE_HTML_FILE="$MAINTENANCE_HTML_PATH/index.html"



function SSL_generate_cert(){
    # If a valid SSL certificate is not already created for the server, create a self-signed certificate:
    while [ -f $PID_CERT_CREATER ]
    do
        echo "`date +%T` -  misp-server container create currently the certificate. misp-proxy until misp-server is finish."
    done
    
    [ ! -f $SSL_CERT -a ! -f $SSL_KEY ] && touch $PID_CERT_CREATER && echo "Create SSL Certificate..." && openssl req -x509 -newkey rsa:4096 -keyout $SSL_KEY -out $SSL_CERT -days 365 -sha256 -subj '/CN=${HOSTNAME}' -nodes && echo "finished." && rm $PID_CERT_CREATER
    
    echo # add an echo command because if no command is done busybox (alpine sh) won't continue the script
}

function SSL_generate_DH(){
    [ ! -f $SSL_DH_FILE ] && echo "Create DH params - This can take a long time, so take a break and enjoy a cup of tea or coffee." && openssl dhparam -out $SSL_DH_FILE 2048
    echo # add an echo command because if no command is done busybox (alpine sh) won't continue the script
}

function deactivate_http_config(){
    [ -f $HTTP_CONFIG.conf ] && echo "mv $HTTP_CONFIG.conf $HTTP_CONFIG" && mv $HTTP_CONFIG.conf $HTTP_CONFIG
    echo # add an echo command because if no command is done busybox (alpine sh) won't continue the script
}

function activate_https_config()
{
    [ -f $HTTPS_CONFIG ] && echo "mv $HTTPS_CONFIG $HTTPS_CONFIG.conf" && mv $HTTPS_CONFIG $HTTPS_CONFIG.conf
    echo # add an echo command because if no command is done busybox (alpine sh) won't continue the script
}

function file_GLOBAL_allow_IPs(){
cat << EOF > $GLOBAL_allow_IPs
allow all;
EOF

chmod 644 $GLOBAL_allow_IPs
echo # add an echo command because if no command is done busybox (alpine sh) won't continue the script
}

function file_vars_common()
{  
cat << EOF > $VARS_COMMON
server_name $HOSTNAME;
client_max_body_size 50M;

EOF
chmod 644 $VARS_COMMON
echo # add an echo command because if no command is done busybox (alpine sh) won't continue the script
}

function file_maintenance_html(){

[ ! -d $MAINTENANCE_HTML_PATH ] && echo "mkdir -p $MAINTENANCE_HTML_PATH" && mkdir -p $MAINTENANCE_HTML_PATH; # Add directory for maintenance File + Copy Maintenance config

cat << EOF > $MAINTENANCE_HTML_FILE
<!doctype html>
<title>Site Maintenance</title>
<style>
  body { text-align: center; padding: 150px; }
  h1 { font-size: 50px; }
  body { font: 20px Helvetica, sans-serif; color: #333; }
  article { display: block; text-align: left; width: 650px; margin: 0 auto; }
  a { color: #dc8100; text-decoration: none; }
  a:hover { color: #333; text-decoration: none; }
</style>

<article>
    <h1>We&rsquo;ll be back soon!</h1>
    <div>
        <p>Sorry for the inconvenience but we&rsquo;re performing some maintenance at the moment. If you need to you can always <a href="mailto:${HTTP_SERVERADMIN}?Subject=MISP-dockerized Maintenance at ${HOSTNAME}">contact us</a>, otherwise we&rsquo;ll be back online shortly!</p>
        <p>&mdash; Your MISP Support Team</p>
    </div>
</article>

EOF
echo
}

function enable_maintenance(){
    # deactivate https
    [ -f $HTTPS_CONFIG.conf ] && echo "mv $HTTPS_CONFIG.conf $HTTPS_CONFIG" && mv $HTTPS_CONFIG.conf $HTTPS_CONFIG
    [ -f $MAINTENANCE ] && echo "mv $MAINTENANCE $MAINTENANCE.conf" && mv $MAINTENANCE $MAINTENANCE.conf
    nginx -t
    echo # add an echo command because if no command is done busybox (alpine sh) won't continue the script
    exit
}

function disable_maintenance(){
    [ -f $HTTPS_CONFIG ] && mv $HTTPS_CONFIG $HTTPS_CONFIG.conf
    [ -f $MAINTENANCE.conf ] && mv $MAINTENANCE.conf $MAINTENANCE
    nginx -t
    echo # add an echo command because if no command is done busybox (alpine sh) won't continue the script
    exit
}

#####################   MAIN    ###################
# generate vars_common
file_vars_common
# generate global_allow_IPs
file_GLOBAL_allow_IPs
# check if ssl cert is required to generate
SSL_generate_cert
# check if DH file is required to generate
SSL_generate_DH
# create maintenance file
file_maintenance_html

# activate maintenance
[ "$1" == "enable-maintenance" ] && enable_maintenance

# deactivate maintenance
[ "$1" == "disable-maintenance" ] && disable_maintenance

# test nginx config
nginx -t

# if no param is given
[ -z "$1" ] && exec nginx -g "daemon off;"

# execute any COMMAND
exec $@