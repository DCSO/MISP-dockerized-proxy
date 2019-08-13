#!/bin/sh
set -e

STARTMSG="[ENTRYPOINT_APACHE]"

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
FOLDER_with_VERSIONS="/etc/nginx/ssl /etc/nginx/conf.d"

# shellcheck disable=SC2039
MISP_FQDN=${MISP_FQDN:-"$HOSTNAME"}
CLIENT_MAX_BODY_SIZE=${PROXY_CLIENT_MAX_BODY_SIZE:-"50M"}

echo() {
    command echo "$STARTMSG $*"
}

SSL_generate_cert(){
    # If a valid SSL certificate is not already created for the server, create a self-signed certificate:
    i=0
    while [ -f "$PID_CERT_CREATER.server" ]
    do
        echo "$STARTMSG $(date +%T) -  misp-server container create currently the certificate. misp-proxy until misp-server is finish."
        # added to escape a deadlock from proxy 1.4-alpine with misp server 2.4.97-2.4.99.
        i=$((i+1))
        sleep 2
        [ "$i" -eq 30 ] && rm -v "$PID_CERT_CREATER.server"
        # END added to escape a deadlock from proxy 1.4-alpine with misp server 2.4.97-2.4.99.
    done
    
    if [ ! -f "$SSL_CERT" ] && [ ! -f "$SSL_KEY" ]; then
        touch "$PID_CERT_CREATER.proxy" && echo "Create SSL Certificate..." 
        openssl req -x509 -newkey rsa:4096 -keyout $SSL_KEY -out $SSL_CERT -days 365 -sha256 -subj "/C=DE/CN=${MISP_FQDN}" -nodes 
        rm -v $PID_CERT_CREATER.proxy
    fi
    echo # add an echo command because if no command is done busybox (alpine sh) won't continue the script
}

SSL_generate_DH(){
    # If a valid SSL certificate is not already created for the server, create a self-signed certificate:
    i=0
    while [ -f "$PID_CERT_CREATER.server" ]
    do
        echo "$(date +%T) -  misp-server container create currently the certificate. misp-proxy until misp-server is finish."
        # added to escape a deadlock from proxy 1.4-alpine with misp server 2.4.97-2.4.99.
        i=$((i+1))
        sleep 2
        [ "$i" -eq 30 ] && rm -v $PID_CERT_CREATER.server
        # END added to escape a deadlock from proxy 1.4-alpine with misp server 2.4.97-2.4.99.
    done
    
    [ ! -f "$SSL_DH_FILE" ] && touch $PID_CERT_CREATER.proxy && echo "Create DH params - This can take a long time, so take a break and enjoy a cup of tea or coffee." && openssl dhparam -out $SSL_DH_FILE 2048 && rm $PID_CERT_CREATER.proxy
    command echo # add an echo command because if no command is done busybox (alpine sh) won't continue the script
}

deactivate_http_config(){
    [ -f "$HTTP_CONFIG.conf" ] && echo "mv $HTTP_CONFIG.conf $HTTP_CONFIG" && mv -v $HTTP_CONFIG.conf $HTTP_CONFIG
    command echo # add an echo command because if no command is done busybox (alpine sh) won't continue the script
}

activate_https_config()
{
    [ -f "$HTTPS_CONFIG" ] && echo "mv $HTTPS_CONFIG $HTTPS_CONFIG.conf" && mv -v $HTTPS_CONFIG $HTTPS_CONFIG.conf
    command echo # add an echo command because if no command is done busybox (alpine sh) won't continue the script
}

file_GLOBAL_allow_IPs(){
IP="$1"


if [ -z "$IP" ]
then
    # If no param is given allow all IP
cat << EOF > "$GLOBAL_allow_IPs"
allow all;
EOF
else
    # If param is given include only the valid ips
[ -f "$GLOBAL_allow_IPs" ] && rm -v "$GLOBAL_allow_IPs"

for i in $IP
do
cat << EOF >> "$GLOBAL_allow_IPs"
allow $i;
EOF
done

fi


chmod 644 "$GLOBAL_allow_IPs"
command echo # add an echo command because if no command is done busybox (alpine sh) won't continue the script
}

file_vars_common()
{  
cat << EOF > $VARS_COMMON
server_name $MISP_FQDN;
client_max_body_size $CLIENT_MAX_BODY_SIZE;

EOF
chmod 644 "$VARS_COMMON"
command echo # add an echo command because if no command is done busybox (alpine sh) won't continue the script
}

file_maintenance_html(){

[ ! -d $MAINTENANCE_HTML_PATH ] && echo "$STARTMSG mkdir -p $MAINTENANCE_HTML_PATH" && mkdir -p $MAINTENANCE_HTML_PATH; # Add directory for maintenance File + Copy Maintenance config

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
        <p>Sorry for the inconvenience but we&rsquo;re performing some maintenance at the moment. If you need to you can always <a href="mailto:${HTTP_SERVERADMIN}?Subject=MISP-dockerized Maintenance at ${MISP_FQDN}">contact us</a>, otherwise we&rsquo;ll be back online shortly!</p>
        <p>&mdash; Your MISP Support Team</p>
    </div>
</article>

EOF
command echo
}

enable_maintenance(){
    # deactivate https
    [ -f "$HTTPS_CONFIG.conf" ] && echo "mv $HTTPS_CONFIG.conf $HTTPS_CONFIG" && mv -v $HTTPS_CONFIG.conf $HTTPS_CONFIG
    [ -f "$MAINTENANCE" ] && echo "mv $MAINTENANCE $MAINTENANCE.conf" && mv -v $MAINTENANCE $MAINTENANCE.conf
    nginx -t
    command echo # add an echo command because if no command is done busybox (alpine sh) won't continue the script
    exit
}

disable_maintenance(){
    [ -f "$HTTPS_CONFIG" ] && echo "mv $HTTPS_CONFIG $HTTPS_CONFIG.conf" && mv -v $HTTPS_CONFIG $HTTPS_CONFIG.conf
    [ -f "$MAINTENANCE.conf" ] && echo "mv $MAINTENANCE.conf $MAINTENANCE" && mv -v $MAINTENANCE.conf $MAINTENANCE
    nginx -t
    command echo # add an echo command because if no command is done busybox (alpine sh) won't continue the script
    exit
}

upgrade(){
    for i in $FOLDER_with_VERSIONS
    do
        if [ ! -f "$i/${NAME}" ] 
        then
            # File not exist and now it will be created
            command echo "${VERSION}" > "$i/${NAME}"
        elif [ ! -f "$i/${NAME}" ] && [ -z "$(cat "$i/${NAME}")" ]
        then
            # File exists, but is empty
            command echo "${VERSION}" > "$i/${NAME}"
        elif [ "$VERSION" = "$(cat "$i/${NAME}")" ]
        then
            # File exists and the volume is the current version
            command echo "Folder $i is on the newest version."
        else
            # upgrade
            echo "Folder $i should be updated."
            case "$i/$NAME" in
            "1.4")
                # Tasks todo in 2.4.92
                echo "#### Upgrade Volumes from 2.4.92 ####"
                ;;
            *)
                echo "Unknown Version, upgrade not possible."
                exit
                ;;
            esac
            ############ DO ANY!!!
        fi
    done
    echo
}

#####################   MAIN    ###################
# generate vars_common
echo "Create variables file..." && file_vars_common
# generate global_allow_IPs
echo "Create file for IP restrictions..." && file_GLOBAL_allow_IPs "$IP"
# check if ssl cert is required to generate
echo "Check if cert is required..." && SSL_generate_cert
# check if DH file is required to generate
echo "Check if DH is required..." && SSL_generate_DH
# create maintenance file
echo "Create maintenance file..." && file_maintenance_html
# check volumes and upgrade if it is required
#echo "$STARTMSG check if upgrade is required..." && upgrade

# activate maintenance
[ "$1" = "enable-maintenance" ] && enable_maintenance

# deactivate maintenance
[ "$1" = "disable-maintenance" ] && disable_maintenance

# test nginx config
nginx -t

# if no param is given
[ -z "$1" ] && exec nginx -g "daemon off;"

# execute any COMMAND
exec "$@"
