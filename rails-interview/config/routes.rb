Rails.application.routes.draw do
  if Rails.env.development?
    require "sidekiq/web"
    mount Sidekiq::Web => "/sidekiq"
  end
  namespace :api, defaults: { format: :json } do
    resources :todo_lists, only: %i[index create update destroy], path: :todolists do
      resources :todos, only: %i[index create update destroy], controller: :items, module: :todo_lists do
        collection do
          patch :bulk_update
        end
      end
    end
  end

  resources :todo_lists, path: :todolists do
    resources :items, only: %i[create update destroy] do
      member do
        patch :complete
      end

      collection do
        patch :complete_selected
        patch :complete_all
      end
    end
  end

  root 'todo_lists#index'
end
