#!/bin/sh
set -e

if env -i REQUEST_METHOD=GET SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping cgi-fcgi -bind -connect php:3000; then
	exit 0
fi

exit 1
