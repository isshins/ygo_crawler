#!/bin/sh

if [ "${RAILS_ENV}" = "production" ]
then
  echo "now is production"
  bundle exec rails assets:precompile
fi

echo "run start-server.sh" &
rails server -p ${PORT:-3000} -b 0.0.0.0
