Observ::Engine.routes.draw do
  root to: "dashboard#index"

  get "dashboard", to: "dashboard#index", as: :dashboard
  get "dashboard/metrics", to: "dashboard#metrics"
  get "dashboard/cost_analysis", to: "dashboard#cost_analysis"

  resources :chats, only: [ :index, :new, :create, :show ] do
    resources :messages, only: [ :create ]
  end

  resources :sessions, only: [ :index, :show ] do
    member do
      get :metrics
      get :drawer_test
      get :annotations_drawer
    end
    resources :annotations, only: [ :index, :create, :destroy ]
  end

  resources :traces, only: [ :index, :show ] do
    collection do
      get :search
    end
    member do
      get :annotations_drawer
    end
    resources :annotations, only: [ :index, :create, :destroy ]
  end

  resources :observations, only: [ :index, :show ] do
    collection do
      get :generations
      get :spans
    end
  end

  get "annotations/sessions", to: "annotations#sessions_index", as: :sessions_annotations
  get "annotations/traces", to: "annotations#traces_index", as: :traces_annotations
  get "annotations/export", to: "annotations#export", as: :export_annotations

  resources :prompts do
    member do
      get :versions              # Version history view
      get :compare               # Compare versions
    end

    resources :versions, only: [ :show ], controller: "prompt_versions" do
      member do
        post :promote    # draft -> production
        post :demote     # production -> archived
        post :restore    # archived -> production
        post :clone      # create editable draft copy
      end
    end
  end
end
