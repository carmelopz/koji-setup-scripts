#!/bin/bash
# Copyright (C) 2018 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

set -xe
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR"/parameters.sh

yum -y install git

## GITOLITE SETUP
yum -y install gitolite3
mkdir -p "$GIT_DIR"
chown -R "$GIT_USER":"$GIT_USER" "$GIT_DIR"
# Add symlink for backwards compatibility
if [[ "$GIT_DIR" != "$GIT_DEFAULT_DIR" ]]; then
	if [ "$(ls -A "$GIT_DEFAULT_DIR")" ]; then
		mv "$GIT_DEFAULT_DIR" "$GIT_DEFAULT_DIR".old
	else
		rm -rf "$GIT_DEFAULT_DIR"
	fi
	ln -sf "$GIT_DIR" "$GIT_DEFAULT_DIR"
	chown -h "$GIT_USER":"$GIT_USER" "$GIT_DEFAULT_DIR"
fi
GITOLITE_PUB_KEY_FILE="$GIT_DEFAULT_DIR/gitolite.pub"
echo "$GITOLITE_PUB_KEY" > "$GITOLITE_PUB_KEY_FILE"
chown "$GIT_USER":"$GIT_USER" "$GITOLITE_PUB_KEY_FILE"
sudo -u "$GIT_USER" gitolite setup -pk "$GITOLITE_PUB_KEY_FILE"


if $IS_ANONYMOUS_GIT_NEEDED; then
	## GIT PROTOCOL CLONING
	yum -y install git-daemon
	mkdir -p /etc/systemd/system
	cat > /etc/systemd/system/git\@.service <<- EOF
	[Unit]
	Description=Git Repositories Server Daemon
	Documentation=man:git-daemon(1)

	[Service]
	User=$GIT_USER
	ExecStart=-/usr/libexec/git-core/git-daemon --base-path=$GIT_DEFAULT_DIR/repositories --inetd --verbose
	StandardInput=socket
	EOF
	systemctl daemon-reload
	systemctl enable --now git.socket


	## CGIT WEB INTERFACE
	yum -y install httpd cgit python-pygments

	# Remove default hosting configurations
	pushd /etc/httpd/conf.d
	echo -n > userdir.conf
	echo -n > welcome.conf
	popd

	cat > /etc/cgitrc <<- EOF
	# Enable caching of up to 1000 output entries
	cache-size=10

	# Specify the css url
	css=/cgit-data/cgit.css

	# Show extra links for each repository on the index page
	enable-index-links=1

	# Enable ASCII art commit history graph on the log pages
	enable-commit-graph=1

	# Show number of affected files per commit on the log pages
	enable-log-filecount=1

	# Show number of added/removed lines per commit on the log pages
	enable-log-linecount=1

	# Use a custom logo
	logo=/cgit-data/cgit.png

	# Enable statistics per week, month and quarter
	max-stats=quarter

	# Allow download of tar.gz, tar.bz2 and zip-files
	snapshots=tar.gz tar.bz2

	##
	## List of common mimetypes
	##
	mimetype.gif=image/gif
	mimetype.html=text/html
	mimetype.jpg=image/jpeg
	mimetype.jpeg=image/jpeg
	mimetype.pdf=application/pdf
	mimetype.png=image/png
	mimetype.svg=image/svg+xml

	# Enable syntax highlighting and about formatting
	source-filter=/usr/libexec/cgit/filters/syntax-highlighting.py
	about-filter=/usr/libexec/cgit/filters/about-formatting.sh

	##
	## List of common readmes
	##
	readme=:README.md
	readme=:readme.md
	readme=:README.mkd
	readme=:readme.mkd
	readme=:README.rst
	readme=:readme.rst
	readme=:README.html
	readme=:readme.html
	readme=:README.htm
	readme=:readme.htm
	readme=:README.txt
	readme=:readme.txt
	readme=:README
	readme=:readme
	readme=:INSTALL.md
	readme=:install.md
	readme=:INSTALL.mkd
	readme=:install.mkd
	readme=:INSTALL.rst
	readme=:install.rst
	readme=:INSTALL.html
	readme=:install.html
	readme=:INSTALL.htm
	readme=:install.htm
	readme=:INSTALL.txt
	readme=:install.txt
	readme=:INSTALL
	readme=:install

	# Direct cgit to repository location managed by gitolite
	remove-suffix=1
	project-list=$GIT_DEFAULT_DIR/projects.list
	scan-path=$GIT_DEFAULT_DIR/repositories
	EOF

	mkdir -p /etc/httpd/conf.d
	cat > /etc/httpd/conf.d/cgit.conf <<- EOF
	Alias /cgit-data /usr/share/cgit
	ScriptAlias /cgit /var/www/cgi-bin/cgit
	<Directory "/usr/share/cgit">
		Require all granted
	</Directory>
	EOF
	usermod -a -G "$GIT_USER" "$HTTPD_USER"

	systemctl restart httpd
	systemctl enable httpd
fi