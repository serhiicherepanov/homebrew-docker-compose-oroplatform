#!/bin/bash
set -e

#OWNER_UID=$(stat -c '%u' ${APP_DIR:-/var/www})
#OWNER_GID=$(stat -c '%g' ${APP_DIR:-/var/www})

# usermod -u $OWNER_UID -o www-data && groupmod -g $OWNER_GID -o www-data

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- php-fpm "$@"
fi

if [[ -d "${APP_DIR:-/var/www}/.git" ]]; then
	git config --global --add safe.directory "${APP_DIR:-/var/www}/.git"
fi
PHP_USER_HOME=$(eval echo "~$PHP_USER_NAME")
cat > ${PHP_USER_HOME}/.profile <<- EOM
	cd \${APP_DIR:-/var/www}
EOM

if [[ -f /.zshrc ]]; then
	rm -f ${PHP_USER_HOME}/.zshrc
	cp /.zshrc ${PHP_USER_HOME}/.zshrc
	cat >> ${PHP_USER_HOME}/.zshrc <<- EOM

		cd \${APP_DIR:-/var/www}
	EOM
fi

if [[ $XDEBUG_MODE = "off" ]]; then
	rm -f "${PHP_INI_DIR}/conf.d/docker-php-ext-xdebug.ini" 2>/dev/null || true
	rm -f "${PHP_INI_DIR}/conf.d/app.xdebug.ini" 2>/dev/null || true
fi

# Install mailpit certificate to system trust store if using TLS
if [[ -f "/certs/mail.crt" ]] && [[ "${ORO_MAILER_ENCRYPTION}" =~ ^(tls|ssl)$ ]]; then
	echo "[INFO] Installing mailpit certificate to system trust store..."
	sudo cp /certs/mail.crt /usr/local/share/ca-certificates/mailpit.crt 2>/dev/null || true
	sudo update-ca-certificates 2>/dev/null > /dev/null || true
	echo "[INFO] Mailpit certificate installed"
fi

chmod +x ${PHP_USER_HOME}/.profile

export PHP_IDE_CONFIG="serverName=$(hostname | cut -d. -f2-)"

exec docker-php-entrypoint "$@"