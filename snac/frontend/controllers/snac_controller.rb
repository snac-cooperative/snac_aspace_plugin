# Modified by SNAC
require 'snacsearcher'
require 'securerandom'

class SnacController < ApplicationController

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
    #marcxml_file = searcher.results_to_marcxml_file(SNACQuery.query_list_marcxml(params[:snacid]))
    marcxml_file = SNACQuery.query_list_marcxml(params[:snacid])

    begin
      job = Job.new("import_job", {
                      "import_type" => "marcxml_snac_subjects_and_agents",
                      "jsonmodel_type" => "import_job"
                      },
                    {"snac_import_#{SecureRandom.uuid}" => marcxml_file})

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
    #SNACSearcher.new('http://snac-dev.iath.virginia.edu/alpha/www/search')
    SNACSearcher.new('https://snaccooperative.org/search')
  end
end
