# Modified by SNAC
require 'snacsearcher'
require 'securerandom'
require_relative '../../common/snac_preferences'
require_relative '../../common/snac_api_client'

class SnacController < ApplicationController

  class SnacControllerException < StandardError; end

  set_access_control "update_agent_record" => [:search, :index, :import, :export, :link, :unlink]
  set_access_control "update_resource_record" => [:export, :link, :unlink]
  set_access_control "import_records" => [:search, :index, :import]
  set_access_control "create_job" => [:export, :link, :unlink]
  set_access_control "view_repository" => [:resolve, :lookup]


  def index
    get_prefs

    @page = 1
    @records_per_page = 15
  end


  def search
    begin
      get_prefs
      res = searcher.search(params[:name_entry], params[:page].to_i, params[:records_per_page].to_i)
    rescue
      res = { :error => $! }
    end

    render :json => res.to_json
  end


  def import
    json_file = ASUtils.tempfile('snac_import')
    json_file.write(params[:records].to_json)
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
                 "uris" => params[:uris]
               },
               {})
  end


  def resolve
    res = { :error => '' }

    client = SnacApiClient.new(get_prefs)

    begin
      results = []

      case params[:type]
      when 'agent'
        json = client.search_constellations(params[:snac_term])
        json['results'].each do |r|
          results << {
            :id => r['id'],
            :title => r['nameEntries'][0]['original'],
            :snac_url => get_prefs.view_url(r['id'])
          }
        end
      when 'resource'
        json = client.search_resources(params[:snac_term])
        json['results'].each do |r|
          results << {
            :id => r['id'],
            :title => r['title'],
            :snac_url => get_prefs.resource_url(r['id'])
          }
        end
      end

      res[:results] = results
    rescue
      res[:error] = $!
    end

    respond_to do |format|
      format.js { render :locals => {:res => res} }
    end
  end


  def lookup
    res = { :error => '' }

    client = SnacApiClient.new(get_prefs)

    begin
      results = []

      case params[:type]
      when 'agent'
        json = client.read_constellation(params[:snac_source])
        results << {
          :id => json['constellation']['id'],
          :title => json['constellation']['nameEntries'][0]['original'],
          :snac_url => get_prefs.view_url(json['constellation']['id'])
        }
      when 'resource'
        json = client.read_resource(params[:snac_source])
        results << {
          :id => json['resource']['id'],
          :title => json['resource']['title'],
          :snac_url => get_prefs.resource_url(json['resource']['id'])
        }
      end

      res[:results] = results
    rescue
      res[:error] = $!
    end

    respond_to do |format|
      format.js { render :locals => {:res => res} }
    end
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
    @prefs
  end


  def searcher
    SnacSearcher.new(@prefs.search_url)
  end


end
