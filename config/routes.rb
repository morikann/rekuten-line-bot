Rails.application.routes.draw do
  post '/callback', to: 'linbots#callback'
end
