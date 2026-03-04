Rails.application.routes.draw do
  constraints(format: :json) do
    scope module: :api, defaults: { format: :json }, path: '' do
      resources :todo_lists, only: %i[index create update destroy], path: :todolists do
        resources :items, only: %i[update destroy], controller: 'todo_lists/items',
                     path: :todoitems, param: :todoitem_id
      end
    end
  end

  resources :todo_lists, only: %i[index new], path: :todolists
end
