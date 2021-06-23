# Modified by SNAC
require 'snacsearcher'
require 'securerandom'
require_relative '../../common/snac_environment'

class SnacController < ApplicationController

  class SNACControllerException < StandardError; end

  set_access_control "update_agent_record" => [:search, :index, :import]


  def index
    @page = 1
    @records_per_page = 15
  end


  def search
    results = do_search(params)
    render :json => results.to_json
  end


  def import
    ids_file = ASUtils.tempfile('snac_import')
    ids_file.write(params[:snacid].to_json)
    ids_file.flush
    ids_file.rewind

    begin
      job = Job.new("import_job", {
                      "import_type" => "snac_constellation_ids",
                      "jsonmodel_type" => "import_job"
                      },
                    {"snac_import_#{SecureRandom.uuid}" => ids_file})

      response = job.upload
      render :json => {'job_uri' => url_for(:controller => :jobs, :action => :show, :id => response['id'])}
    rescue
      render :json => {'error' => $!.to_s}
    end
  end


  private


  def do_search(params)
    searcher.search(params[:family_name], params[:page].to_i, params[:records_per_page].to_i)
  end


  def searcher
    SNACSearcher.new(SnacEnvironment.search_url)
  end
end