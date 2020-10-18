Rails.application.routes.draw do
  post '/callback', to: 'linebots#callback'
end
