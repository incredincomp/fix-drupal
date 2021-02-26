#!/usr/bin/bash
# fix a drupal site on apache that you didnt set up with composer
# needs to be run from inside your web root (/var/www/) 
# feed it your messed up drupal path

drupal_path=${1%/}
username=${USER}

install_composer(){
composer_bin="$(which composer 2>/dev/null)"
if [ -z $composer_bin ]; then
  cd /var/www/
  EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
  ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

  if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]
  then
    >&2 echo 'ERROR: Invalid installer checksum'
    rm composer-setup.php
    exit 1
  fi

  php composer-setup.php --quiet
  rm composer-setup.php
  mv composer.phar /usr/local/bin/composer
  RESULT=$?
  if [ $RESULT -eq "1" ]; then
    sudo -u "$username" mv composer.phar /usr/local/bin/composer
  fi
fi
}

backup_path(){
if [ -d /var/www/drupal/ ]; then
  sudo mv "$drupal_path" /var/www/old_drupal
else
  sudo mv "$drupal_path" /var/www/old_drupal
fi
}

create_project(){
  sudo -u "$username" composer create-project drupal/recommended-project /var/www/drupal
}

transfer_site(){
  cp /var/www/old_drupal/settings.php /var/www/drupal/web/settings.php
  cp -r /var/www/old_drupal/modules /var/www/drupal/web/modules
  cp -r /var/www/old_drupal/themes /var/www/drupal/web/themes
  cp /var/www/old_drupal/.htaccess /var/www/drupal/web/.htaccess

}

fix_permissions(){
# https://gist.github.com/chrisjlee/2719927
path="/var/www/drupal/"
user=$username
group="www-data"

usermod -a -G "$group" "$user"

cd $path;

echo -e "Changing ownership of all contents of \"${path}\" :\n user => \"${user}\" \t group => \"${group}\"\n"
chown -R ${user}:${group} .
echo "Changing permissions of all directories inside \"${path}\" to \"750\"..."
find . -type d -exec chmod u=rwx,g=rx,o= {} \;
echo -e "Changing permissions of all files inside \"${path}\" to \"640\"...\n"
find . -type f -exec chmod u=rw,g=r,o= {} \;

cd $path/sites;

echo "Changing permissions of \"files\" directories in \"${path}/sites\" to \"770\"..."
find . -type d -name files -exec chmod ug=rwx,o= '{}' \;
echo "Changing permissions of all files inside all \"files\" directories in \"${path}/sites\" to \"660\"..."
find . -name files -type d -exec find '{}' -type f \; | while read FILE; do chmod ug=rw,o= "$FILE"; done
echo "Changing permissions of all directories inside all \"files\" directories in \"${path}/sites\" to \"770\"..."
find . -name files -type d -exec find '{}' -type d \; | while read DIR; do chmod ug=rwx,o= "$DIR"; done
}

main(){
  install_composer
  backup_path
  create_project
  fix_permissions
}
main
