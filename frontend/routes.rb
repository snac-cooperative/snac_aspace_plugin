# Modified by SNAC
ArchivesSpace::Application.routes.draw do
  scope AppConfig[:frontend_proxy_prefix] do
    match '/plugins/snac_aspace_plugin' => 'snac#index', :via => [:get]
    match '/plugins/snac_aspace_plugin/search' => 'snac#search', :via => [:get]
    match '/plugins/snac_aspace_plugin/import' => 'snac#import', :via => [:post]
    match 'agents/:agent_type/:id/export' => 'snac#export', :via => [:post]
    match 'agents/:agent_type/:id/sync' => 'snac#sync', :via => [:post]
    match 'agents/:agent_type/:id/push' => 'snac#push', :via => [:post]
    match 'agents/:agent_type/:id/pull' => 'snac#pull', :via => [:post]
    match 'agents/:agent_type/:id/link' => 'snac#link', :via => [:post]
    match 'agents/:agent_type/:id/unlink' => 'snac#unlink', :via => [:post]
    match 'agents/:agent_type/:id/resolve' => 'snac#resolve', :via => [:post]
    match 'agents/:agent_type/:id/lookup' => 'snac#lookup', :via => [:post]
    match 'resources/:id/export' => 'snac#export', :via => [:post]
    match 'resources/:id/sync' => 'snac#sync', :via => [:post]
    match 'resources/:id/push' => 'snac#push', :via => [:post]
    match 'resources/:id/pull' => 'snac#pull', :via => [:post]
    match 'resources/:id/link' => 'snac#link', :via => [:post]
    match 'resources/:id/unlink' => 'snac#unlink', :via => [:post]
    match 'resources/:id/resolve' => 'snac#resolve', :via => [:post]
    match 'resources/:id/lookup' => 'snac#lookup', :via => [:post]
  end
end
