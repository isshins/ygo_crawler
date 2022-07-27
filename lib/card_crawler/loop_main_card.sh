 #!/bin/sh

while true
do
  echo "Ruby 起動" `date`
  bundle exec ruby lib/card_crawler/main_card_crawler.rb
  echo "Ruby 終了" `date`

  sleep 60
done
