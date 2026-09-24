class DashboardController < ApplicationController
  def show
    authorize :dashboard, :show?

    @job_applications = current_user.job_applications
                                    .includes(job_opening: :company)
                                    .order(created_at: :desc)
    @status_counts = JobApplication.statuses.values.index_with do |status|
      @job_applications.count { |application| application.status == status }
    end

    @personal_tasks = current_user.tasks
                                  .where(job_application_id: nil, completed: false)
                                  .order(:position, :created_at)
                                  .limit(4)
    @application_tasks = current_user.tasks
                                     .where.not(job_application_id: nil)
                                     .where(completed: false)
                                     .includes(job_application: { job_opening: :company })
                                     .order(:position, :created_at)
                                     .limit(4)

    applied_job_ids = @job_applications.map(&:job_opening_id)
    @job_openings = policy_scope(JobOpening)
                    .where(closed: false)
                    .where.not(id: applied_job_ids)
                    .includes(:company)
                    .order(Arel.sql("deadline IS NULL, deadline ASC"), created_at: :desc)
                    .where(source: "Japandev")
                    .limit(4)
  end
end
