#!/bin/sh
set -e

SSL_DH_FILE="/etc/nginx/ssl/dhparams.pem"
SSL_KEY="/etc/nginx/ssl/key.pem"
SSL_CERT="/etc/nginx/ssl/cert.pem"
VARS_COMMON="/etc/nginx/conf.d/vars_common"
GLOBAL_allow_IPs=/etc/nginx/conf.d/GLOBAL_allow_IPs
HTTPS_CONFIG="/etc/nginx/conf.d/SERVER_HTTPS_and_redirected_HTTP"
HTTP_CONFIG="/etc/nginx/conf.d/SERVER_HTTP_only"
MAINTENANCE="/etc/nginx/conf.d/SERVER_MAINTENANCE"

function SSL_create_cert(){
    # If a valid SSL certificate is not already created for the server, create a self-signed certificate:
    [ ! -f $SSL_CERT -a ! -f $SSL_KEY ] && openssl req -x509 -newkey rsa:4096 -keyout $SSL_KEY -out $SSL_CERT -days 365 -sha256 -subj '/CN=${HOSTNAME}' -nodes
}

function SSL_generate_DH(){
    [ ! -f $SSL_DH_FILE ] && echo "Create DH params - This can take a long time, so take a break and enjoy a cup of tea or coffee." && openssl dhparam -out $SSL_DH_FILE 2048
}

function deactivate_http_config(){
    [ -f $HTTP_CONFIG.conf ] && echo "mv $HTTP_CONFIG.conf $HTTP_CONFIG" && mv $HTTP_CONFIG.conf $HTTP_CONFIG
}

function activate_https_config()
{
    [ -f $HTTPS_CONFIG ] && echo "mv $HTTPS_CONFIG $HTTPS_CONFIG.conf" && mv $HTTPS_CONFIG $HTTPS_CONFIG.conf
}

function file_GLOBAL_allow_IPs(){
cat << EOF > $GLOBAL_allow_IPs
allow all;
EOF

chmod 644 $GLOBAL_allow_IPs
}

function file_vars_common()
{  
cat << EOF > $VARS_COMMON
server_name $HOSTNAME;
client_max_body_size 50M;

EOF
chmod 644 $VARS_COMMON
}

function activate_maintenance(){
    # deactivate https
    [ -f $HTTPS_CONFIG.conf ] && echo "mv $HTTPS_CONFIG.conf $HTTPS_CONFIG" && mv $HTTPS_CONFIG.conf $HTTPS_CONFIG
    [ -f $MAINTENANCE ] && echo "mv $MAINTENANCE $MAINTENANCE.conf" && mv $MAINTENANCE $MAINTENANCE.conf
}

function deactivate_maintenance(){
    [ -f $HTTPS_CONFIG ] && mv $HTTPS_CONFIG $HTTPS_CONFIG.conf
    [ -f $MAINTENANCE.conf ] && mv $MAINTENANCE.conf $MAINTENANCE
}

#####################   MAIN    ###################
# generate vars_common
file_vars_common
# generate global_allow_IPs
file_GLOBAL_allow_IPs
# check if DH file is required to generate
SSL_generate_DH


# activate maintenance
[ "$1" == "activate-maintenance" ] && activate_maintenance

# deactivate maintenance
[ "$1" == "deactivate-maintenance" ] && deactivate_maintenance

# test nginx config
nginx -t

# if no param is given
[ -z "$1" ] && nginx -g daemon off;

# execute any COMMAND
$@