# Modified by SNAC
ArchivesSpace::Application.routes.draw do
  scope AppConfig[:frontend_proxy_prefix] do
    match '/plugins/snac' => 'snac#index', :via => [:get]
    match '/plugins/snac/search' => 'snac#search', :via => [:get]
    match '/plugins/snac/import' => 'snac#import', :via => [:post]
    match 'agents/:agent_type/:id/export' => 'snac#export', :via => [:post]
    match 'agents/:agent_type/:id/link' => 'snac#link', :via => [:post]
    match 'agents/:agent_type/:id/unlink' => 'snac#unlink', :via => [:post]
    match 'agents/:agent_type/:id/resolve' => 'snac#resolve', :via => [:post]
    match 'agents/:agent_type/:id/lookup' => 'snac#lookup', :via => [:post]
    match 'resources/:id/export' => 'snac#export', :via => [:post]
    match 'resources/:id/link' => 'snac#link', :via => [:post]
    match 'resources/:id/unlink' => 'snac#unlink', :via => [:post]
    match 'resources/:id/resolve' => 'snac#resolve', :via => [:post]
    match 'resources/:id/lookup' => 'snac#lookup', :via => [:post]
  end
end
