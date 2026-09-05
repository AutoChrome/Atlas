# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "@rails/actiontext", to: "@rails--actiontext.js" # @7.2.302
pin "@rails/activestorage", to: "@rails--activestorage.js" # @7.2.302
pin "trix" # @2.1.19
