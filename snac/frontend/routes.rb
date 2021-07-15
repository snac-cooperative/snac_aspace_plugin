# Modified by SNAC
ArchivesSpace::Application.routes.draw do
  scope AppConfig[:frontend_proxy_prefix] do
    match '/plugins/snac' => 'snac#index', :via => [:get]
    match '/plugins/snac/search' => 'snac#search', :via => [:get]
    match '/plugins/snac/import' => 'snac#import', :via => [:post]
    match 'agents/:agent_type/:id/export' => 'snac#export', :via => [:get, :post]
    match 'resources/:id/export' => 'snac#export', :via => [:get, :post]
  end
end
