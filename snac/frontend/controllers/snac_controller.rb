# Modified by SNAC
require 'snacsearcher'
require 'securerandom'
require_relative '../../common/snac_preferences'

class SnacController < ApplicationController

  class SnacControllerException < StandardError; end

  set_access_control "update_agent_record" => [:search, :index, :import, :export, :link, :unlink]
  set_access_control "update_resource_record" => [:export, :link, :unlink]
  set_access_control "import_records" => [:search, :index, :import]
  set_access_control "create_job" => [:export, :link, :unlink]


  def index
    get_prefs

    @page = 1
    @records_per_page = 15
  end


  def search
    get_prefs

    results = do_search(params)
    render :json => results.to_json
  end


  def import
    json_file = ASUtils.tempfile('snac_import')
    json_file.write(params[:items].to_json)
    json_file.flush
    json_file.rewind

    create_job("import_job", {
                 "import_type" => "snac_json",
                 "jsonmodel_type" => "import_job"
               },
               { "snac_import_#{SecureRandom.uuid}" => json_file })
  end


  def export
    create_job("snac_job", {
                 "job_type" => "snac_job",
                 "jsonmodel_type" => "snac_export_job",
                 "action" => "export",
                 "uris" => params[:uris],
                 "include_linked_resources" => params[:include_linked_resources] == '1',
                 "include_linked_agents" => params[:include_linked_agents] == '1'
               },
               {})
  end


  def link
    create_job("snac_job", {
                 "job_type" => "snac_job",
                 "jsonmodel_type" => "snac_link_job",
                 "action" => "link",
                 "uris" => params[:uris],
                 "snac_source" => params[:snac_source]
               },
               {})
  end


  def unlink
    create_job("snac_job", {
                 "job_type" => "snac_job",
                 "jsonmodel_type" => "snac_unlink_job",
                 "action" => "unlink",
                 "uris" => params[:uris],
                 "include_linked_resources" => params[:include_linked_resources] == '1',
                 "include_linked_agents" => params[:include_linked_agents] == '1'
               },
               {})
  end


  private


  def create_job(job_name, job_data, job_files)
    res = {
      :job_uri => '',
      :error => ''
    }

    begin
      job = Job.new(job_name, job_data, job_files)
      response = job.upload

      # response differs for uploads vs. non-uploads; determine job id accordingly
      id = response.key?('uri') ? JSONModel(:job).id_for(response['uri']) : response['id']

      res[:job_uri] = url_for(:controller => :jobs, :action => :show, :id => id)
    rescue
      res[:error] = $!.to_s
    end

    respond_to do |format|
      format.js { render :locals => {:res => res} }
    end
  end


  def get_prefs
    @prefs = SnacPreferences.new(user_prefs) unless @prefs
  end


  def do_search(params)
    searcher.search(params[:name_entry], params[:page].to_i, params[:records_per_page].to_i)
  end


  def searcher
    SnacSearcher.new(@prefs.search_url)
  end


end
