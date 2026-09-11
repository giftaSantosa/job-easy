class ManualApplicationsController < ApplicationController
  def new
    authorize JobApplication, :create?
    JobApplication.new
  end

  def create
    authorize JobApplication, :create?
    company = Company.new(name: manual_applications_params[:company_name])
    job_opening = JobOpening.new(
      title: manual_applications_params[:title],
      job_url: manual_applications_params[:job_url],
      source_url: manual_applications_params[:job_url],
      content: manual_applications_params[:content],
      deadline: manual_applications_params[:deadline],
      salary: manual_applications_params[:salary]
    )
    job_opening.user = current_user
    job_opening.company = company
    @job_application = JobApplication.new(
      job_opening: job_opening,
      user: current_user,
      status: "Saved"
    )
    ActiveRecord::Base.transaction do
      company.save!
      job_opening.save!
      @job_application.save!
    end
    redirect_to job_application_path(@job_application)
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end

  private

  def manual_applications_params
    params.require(:manual_application).permit(:company_name, :title, :job_url, :content, :deadline, :salary)
  end
end
