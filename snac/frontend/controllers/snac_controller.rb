# Modified by SNAC
require 'snacsearcher'
require 'securerandom'
require_relative '../../common/snac_environment'

class SnacController < ApplicationController

  class SNACControllerException < StandardError; end

  set_access_control "update_agent_record" => [:search, :index, :import, :export]


  def index
    @page = 1
    @records_per_page = 15
  end


  def search
    results = do_search(params)
    render :json => results.to_json
  end


  def import
    # eventually this will handle other types of data
    items = []
    params[:snacid].each do |id|
      items << {
        "type" => "constellation",
        "id" => id
      }
    end

    json_file = ASUtils.tempfile('snac_import')
    json_file.write(items.to_json)
    json_file.flush
    json_file.rewind

    begin
      job = Job.new("import_job", {
                      "import_type" => "snac_json",
                      "jsonmodel_type" => "import_job"
                      },
                    {"snac_import_#{SecureRandom.uuid}" => json_file})

      response = job.upload
      render :json => {'job_uri' => url_for(:controller => :jobs, :action => :show, :id => response['id'])}
    rescue
      render :json => {'error' => $!.to_s}
    end
  end


  def export
    res = {
      :job_uri => '',
      :error => ''
    }

    begin
      job = Job.new("snac_export_job", {
                      "job_type" => "snac_export_job",
                      "jsonmodel_type" => "snac_export_job",
                      "uris" => params[:uris]
                    },
                    {})

      response = job.upload
      res[:job_uri] = url_for(:controller => :jobs, :action => :show, :id => JSONModel(:job).id_for(response['uri']))
    rescue
      res[:error] = $!.to_s
    end

    respond_to do |format|
      format.js { render :locals => {:res => res} }
    end
  end


  private


  def do_search(params)
    searcher.search(params[:name_entry], params[:page].to_i, params[:records_per_page].to_i)
  end


  def searcher
    SNACSearcher.new(SnacEnvironment.search_url)
  end
end
