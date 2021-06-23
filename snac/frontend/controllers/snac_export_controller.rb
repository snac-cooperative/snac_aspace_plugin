class SnacExportController < ApplicationController

  set_access_control "view_repository" => [:export_into_snac]

  include ExportHelper

  def export_into_snac
    agent_id = params[:id].to_i
    agent_type = params[:type]

    begin
      job = Job.new("snac_export_job", {
                      "job_type" => "snac_export_job",
                      "jsonmodel_type" => "snac_export_job",
                      "agent_id" => agent_id,
                      "agent_type" => agent_type
                    },
                    {})

      response = job.upload
      redirect_to :controller => :jobs, :action => :show, :id => JSONModel(:job).id_for(response['uri'])
    rescue
      # FIXME: probably doesn't do the right thing
      render :json => {'error' => $!.to_s}
    end
  end

end
