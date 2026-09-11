require "test_helper"

class ManualApplicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user("manual-owner")
    sign_in @user
  end

  # --- new -------------------------------------------------------------------

  test "new renders the form for a signed-in user" do
    get new_manual_application_path

    assert_response :success
    assert_select "form[action=?][method=post]", manual_applications_path
    assert_select "input[name=?]", "manual_application[company_name]"
    assert_select "input[name=?]", "manual_application[title]"
  end

  test "new redirects a signed-out visitor to login" do
    sign_out @user

    get new_manual_application_path

    assert_redirected_to new_user_session_path
  end

  test "applications index links to the new application form" do
    get job_applications_path

    assert_response :success
    assert_select "a[href=?]", new_manual_application_path
  end

  # --- create: happy path ----------------------------------------------------

  test "create saves company, private job opening, and application" do
    assert_difference [ "Company.count", "JobOpening.count", "JobApplication.count" ], 1 do
      post manual_applications_path, params: { manual_application: valid_params }
    end

    application = JobApplication.last
    opening = application.job_opening

    assert_redirected_to job_application_path(application)
    assert_equal @user, application.user
    assert_equal "Saved", application.status
    assert_equal "Backend Engineer", opening.title
    assert_equal "Acme Manual Co", opening.company.name
    assert_equal @user, opening.user, "manual openings must be owned by the user"
    assert_equal Date.new(2026, 10, 1), opening.deadline
  end

  test "created application show page renders" do
    post manual_applications_path, params: { manual_application: valid_params }
    follow_redirect!

    assert_response :success
    assert_includes response.body, "Backend Engineer"
  end

  # --- create: invalid input -------------------------------------------------

  test "blank job title saves nothing and re-renders the form" do
    assert_no_difference [ "Company.count", "JobOpening.count", "JobApplication.count" ] do
      post manual_applications_path, params: { manual_application: valid_params.merge(title: "") }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Title can&#39;t be blank"
  end

  test "blank company name saves nothing and re-renders the form" do
    assert_no_difference [ "Company.count", "JobOpening.count", "JobApplication.count" ] do
      post manual_applications_path, params: { manual_application: valid_params.merge(company_name: "") }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Name can&#39;t be blank"
  end

  # --- company reuse ---------------------------------------------------------

  test "reuses an existing company with the same name" do
    existing = Company.create!(name: "Acme Manual Co")

    assert_no_difference "Company.count" do
      post manual_applications_path, params: { manual_application: valid_params }
    end

    assert_equal existing, JobApplication.last.job_opening.company
  end

  # --- privacy ---------------------------------------------------------------

  test "manual job opening is hidden from the public job openings list" do
    public_opening = JobOpening.create!(company: Company.create!(name: "Scraped Co"), title: "Scraped Role")
    post manual_applications_path, params: { manual_application: valid_params }

    get job_openings_path

    assert_response :success
    assert_includes response.body, public_opening.title
    assert_not_includes response.body, "Backend Engineer"
  end

  test "owner can view their manual job opening" do
    post manual_applications_path, params: { manual_application: valid_params }

    get job_opening_path(JobOpening.last)

    assert_response :success
  end

  test "another user cannot view someone else's manual job opening" do
    post manual_applications_path, params: { manual_application: valid_params }
    opening = JobOpening.last
    sign_out @user
    sign_in create_user("other-user")

    assert_raises(Pundit::NotAuthorizedError) do
      get job_opening_path(opening)
    end
  end

  test "logged-out visitor cannot view a manual job opening" do
    post manual_applications_path, params: { manual_application: valid_params }
    opening = JobOpening.last
    sign_out @user

    assert_raises(Pundit::NotAuthorizedError) do
      get job_opening_path(opening)
    end
  end

  private

  def valid_params
    {
      company_name: "Acme Manual Co",
      title: "Backend Engineer",
      job_url: "https://example.com/jobs/1",
      content: "Build things.",
      deadline: "2026-10-01",
      salary: "¥6M"
    }
  end

  def create_user(prefix)
    User.create!(
      email: "#{prefix}-#{SecureRandom.hex(4)}@example.com",
      password: "password"
    )
  end
end
