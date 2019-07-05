#!/bin/sh
set -eu

# Variables
NC='\033[0m' # No Color
Light_Green='\033[1;32m'  
STARTMSG="${Light_Green}[ENTRYPOINT_PROXY]${NC}"
SSL_DH_FILE="/etc/nginx/ssl/dhparams.pem"
SSL_KEY="/etc/nginx/ssl/key.pem"
SSL_CERT="/etc/nginx/ssl/cert.pem"
VARS_COMMON="/etc/nginx/conf.d/vars_common"
GLOBAL_allow_IPs="/etc/nginx/conf.d/GLOBAL_allow_IPs"
HTTPS_CONFIG="/etc/nginx/conf.d/SERVER_HTTPS_and_redirected_HTTP"
HTTP_CONFIG="/etc/nginx/conf.d/SERVER_HTTP_only"
MAINTENANCE_CONFIG="/etc/nginx/conf.d/SERVER_MAINTENANCE"
STATUS_CONFIG_FILE="/etc/nginx/conf.d/status.conf"
PID_CERT_CREATER="/etc/nginx/ssl/SSL_create.pid"
MAINTENANCE_HTML_PATH="/var/www/maintenance"
MAINTENANCE_HTML_FILE="$MAINTENANCE_HTML_PATH/index.html"
SSL_PASSPHRASE_FILE="/etc/nginx/ssl/ssl.passphrase"

# Functions
echo (){
    command echo -e "$STARTMSG $*"
}


# Environment
MISP_FQDN=${MISP_FQDN:-"misp.example.com"}
MAIL_CONTACT_ADDRESS=${MAIL_CONTACT_ADDRESS:-"no-reply@$MISP_FQDN"}
PROXY_IP_RESTRICTION=${PROXY_IP_RESTRICTION:-"all"}
PROXY_HTTPS_PORT=${PROXY_HTTPS_PORT:-"443"}
PROXY_HTTP_PORT=${PROXY_HTTP_PORT:-"80"}
PROXY_QUESTION_USE_IP_RESTRICTION=${PROXY_QUESTION_USE_IP_RESTRICTION:-"yes"}
PROXY_CLIENT_MAX_BODY_SIZE=${PROXY_CLIENT_MAX_BODY_SIZE:-"50M"}
PROXY_BASIC_AUTH_USER=${PROXY_BASIC_AUTH_USER:-}
PROXY_BASIC_AUTH_PASSWORD=${PROXY_BASIC_AUTH_PASSWORD:-}
SSL_PASSPHRASE=${SSL_PASSPHRASE:-}
SSL_PASSPHRASE_ENABLE=${SSL_PASSPHRASE_ENABLE:-"no"}

#Functions
ssl_generate_cert(){
    # If a valid SSL certificate is not already created for the server, create a self-signed certificate:
    i=0
    while [ -f "$PID_CERT_CREATER.server" ]
    do
        echo "$(date +%T) -  misp-server container create currently the certificate. misp-proxy until misp-server is finish."
        # added to escape a deadlock from proxy 1.4-alpine with misp server 2.4.97-2.4.99.
        i=$((i+1))
        sleep 2
        [ "$i" -eq 30 ] && rm "$PID_CERT_CREATER.server"
        # END added to escape a deadlock from proxy 1.4-alpine with misp server 2.4.97-2.4.99.
    done
    
    if [ ! -f "$SSL_CERT" ] || [ ! -f "$SSL_KEY" ] ; then
     touch "$PID_CERT_CREATER.proxy"
     echo "Create SSL Certificate..."
     openssl req -x509 -newkey rsa:4096 -keyout "$SSL_KEY" -out "$SSL_CERT" -days 365 -sha256 -subj "/C=DE/CN=${MISP_FQDN}" -nodes #--extfile openssl.cnf
     rm "$PID_CERT_CREATER.proxy" 
    fi
    echo "... ssl_generate_cert...finished"
}

ssl_generate_DH(){
    # If a valid SSL certificate is not already created for the server, create a self-signed certificate:
    i=0
    while [ -f "$PID_CERT_CREATER.server" ]
    do
        echo "$(date +%T) -  misp-server container create currently the certificate. misp-proxy until misp-server is finish."
        # added to escape a deadlock from proxy 1.4-alpine with misp server 2.4.97-2.4.99.
        i=$((i+1))
        sleep 2
        [ "$i" -eq 30 ] && rm "$PID_CERT_CREATER.server"
        # END added to escape a deadlock from proxy 1.4-alpine with misp server 2.4.97-2.4.99.
    done
    
    [ ! -f "$SSL_DH_FILE" ] && touch "$PID_CERT_CREATER.proxy" && echo "Create DH params - This can take a long time, so take a break and enjoy a cup of tea or coffee." && openssl dhparam -out $SSL_DH_FILE 2048 && rm $PID_CERT_CREATER.proxy
    echo "... ssl_generate_DH...finished"
}

ssl_passphrase() {
    if [ "$SSL_PASSPHRASE_ENABLE" = "yes" ]
    then
        # Check if SSL_PASSPHRASE as environment variable exists, if not use file
        if [ -n "$SSL_PASSPHRASE" ]
        then
            echo "... ... Copy environment variable into file..."
            command echo "$SSL_PASSPHRASE" > "$SSL_PASSPHRASE_FILE"
            echo "... ... Copy environment variable into file...finished"
        else
            echo "... ... No Environment variable exists will try passphrase file..."
            if [ ! -f "$SSL_PASSPHRASE_FILE" ] 
            then 
                echo "... ... No passphrase file found: $SSL_PASSPHRASE_FILE"
                echo "... ... Please add your file in config/ssl/"
                echo "... ... For more information please go to: https://dcso.github.io/MISP-dockerized-docs/admin/ssl_passphrase.html"
                echo "... ... Exit now."
                exit 1
            fi
        fi
            # Activate configuration
            sed -i "s,.*#ssl_password_file.*,ssl_password_file ${SSL_PASSPHRASE_FILE};," "$HTTPS_CONFIG.conf"
                # write in disabled maintenance config
            [ -f "$MAINTENANCE_CONFIG" ] && sed -i "s,.*#ssl_password_file.*,ssl_password_file ${SSL_PASSPHRASE_FILE};," "$MAINTENANCE_CONFIG"
                # write in enabled maintenance config
            [ -f "$MAINTENANCE_CONFIG.conf" ] && sed -i "s,.*#ssl_password_file.*,ssl_password_file ${SSL_PASSPHRASE_FILE};," "$MAINTENANCE_CONFIG.conf"
            echo "... ... Passphrase file mode enabled."
    else
        echo "... SSL passphrase mode is deactivated."
    fi
}

deactivate_http_config(){
    [ -f "$HTTP_CONFIG.conf" ] && echo "mv $HTTP_CONFIG.conf $HTTP_CONFIG" && mv "$HTTP_CONFIG.conf" "$HTTP_CONFIG"
    echo "... deactivate_http_config...finished"
}

activate_https_config() {
    [ -f "$HTTPS_CONFIG" ] && echo "mv $HTTPS_CONFIG $HTTPS_CONFIG.conf" && mv "$HTTPS_CONFIG" "$HTTPS_CONFIG.conf"
    echo "... activate_https_config...finished"
}

file_global_allow_ips(){
IP="$1"


if [ -z "$IP" ] || [ "$PROXY_QUESTION_USE_IP_RESTRICTION" != "yes" ]
then
    # If no param is given allow all IP
cat << EOF > $GLOBAL_allow_IPs
allow all;
EOF
else
    # If param is given include only the valid ips
    [ -f $GLOBAL_allow_IPs ] && rm $GLOBAL_allow_IPs    
    for i in $IP
    do
cat << EOF >> $GLOBAL_allow_IPs
allow $i;
EOF
    done
    fi

    chmod 644 $GLOBAL_allow_IPs
    echo "... file_global_allow_ips...finished"
}

file_vars_common()
{  
cat << EOF > $VARS_COMMON
server_name $MISP_FQDN;
client_max_body_size $PROXY_CLIENT_MAX_BODY_SIZE;

EOF
chmod 644 $VARS_COMMON
echo "... file_vars_common...finished"
}

file_maintenance_html(){

[ ! -d $MAINTENANCE_HTML_PATH ] && echo "... ... mkdir -p $MAINTENANCE_HTML_PATH" && mkdir -p $MAINTENANCE_HTML_PATH; # Add directory for maintenance File + Copy Maintenance config

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
        <p>Sorry for the inconvenience but we&rsquo;re performing some maintenance at the moment. If you need to you can always <a href="mailto:${MAIL_CONTACT_ADDRESS}?Subject=MISP-dockerized Maintenance at ${MISP_FQDN}">contact us</a>, otherwise we&rsquo;ll be back online shortly!</p>
        <p>&mdash; Your MISP Support Team</p>
    </div>
</article>

EOF
echo "... file_maintenance_html...finished"
}


file_status_conf() {
    ALLOWED_IP_RANGE=""
    for i in $(ip a|grep global|cut -d " " -f 6)
    do
        if grep "127.0.0.1" "$i"; then continue; fi
        ALLOWED_IP_RANGE="${ALLOWED_IP_RANGE}allow $i; "
    done
    cat << EOF > $STATUS_CONFIG_FILE
    server {
        listen 82;

        location /stub_status {
            stub_status on;
            access_log off;
            $ALLOWED_IP_RANGE
            deny all;
        }
    }

EOF
    echo "... file_status_conf...finished"
}

generate_basic_auth(){
    if ( [ -z "$PROXY_BASIC_AUTH_USER" ] || [ -z "$PROXY_BASIC_AUTH_PASSWORD" ] ); then
        echo "Please set PROXY_BASIC_AUTH_PASSWORD and PROXY_BASIC_AUTH_USER environment variables."
    else
        # Create a new basic_auth password file (-c), with bcrypt algorithm (-B) and read the password form commandline (-b)
        htpasswd -cBb /etc/nginx/passwords "$PROXY_BASIC_AUTH_USER" "$PROXY_BASIC_AUTH_PASSWORD"
    fi
}

enable_maintenance(){
    # deactivate https
    [ -f $HTTPS_CONFIG.conf ] && echo "mv $HTTPS_CONFIG.conf $HTTPS_CONFIG" && mv $HTTPS_CONFIG.conf $HTTPS_CONFIG
    [ -f $MAINTENANCE_CONFIG ] && echo "mv $MAINTENANCE_CONFIG $MAINTENANCE_CONFIG.conf" && mv $MAINTENANCE_CONFIG $MAINTENANCE_CONFIG.conf
    nginx -t
    echo "... enable_maintenance...finished"
    exit
}

disable_maintenance(){
    [ -f $HTTPS_CONFIG ] && echo "mv $HTTPS_CONFIG $HTTPS_CONFIG.conf" && mv $HTTPS_CONFIG $HTTPS_CONFIG.conf
    [ -f $MAINTENANCE_CONFIG.conf ] && echo "mv $MAINTENANCE_CONFIG.conf $MAINTENANCE_CONFIG" && mv $MAINTENANCE_CONFIG.conf $MAINTENANCE_CONFIG
    nginx -t
    echo "... disable_maintenance...finished"
    exit
}



#
#####################   MAIN    ###################
#
# generate vars_common
echo "Create variables file..." && file_vars_common
# generate global_allow_IPs
echo "Create file for IP restrictions..." && file_global_allow_ips "$PROXY_IP_RESTRICTION"
# check if ssl cert is required to generate
echo "Check if cert is required..." && ssl_generate_cert
# check if DH file is required to generate
echo "Check if DH is required..." && ssl_generate_DH
# check if SSL passphrase file is required to generate
echo "Check if SSL passphrase is required..." && ssl_passphrase
# create maintenance file
echo "Create maintenance file..." && file_maintenance_html
# create status config for monitoring
echo "Create status config for monitoring..." && file_status_conf
# create basic_auth file
echo "Create Basic Auth File..." && generate_basic_auth

# activate maintenance
[ "${1-}" = "enable-maintenance" ] && echo "Enable Maintenante mode..." && enable_maintenance

# deactivate maintenance
[ "${1-}" = "disable-maintenance" ] && echo "Disable Maintenante mode..." && disable_maintenance


# test nginx config
if ! nginx -t
then
    echo "NGINX configurations failed. Exit now." 
    exit 1
fi


# check if a command parameter exists
if [ $# = 0 ]
then
    exec nginx -g "daemon off;"
else
    # execute any COMMAND
    exec nginx -g "daemon off;" & 
    exec "$@"
fi
