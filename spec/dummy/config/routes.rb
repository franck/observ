Rails.application.routes.draw do
  mount Observ::Engine => "/observ", as: "observ"
end
