class ScrapeCfnJob < ApplicationJob
  queue_as :default
  require 'net/http'
  require 'json'
  require 'uri'
  require 'date'

  def perform
    def fetch_json(url)
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      JSON.parse(response.body)
    end

    def scrape_jd(job_id)
      url = "https://careerforum.net/api/public/jobs/#{job_id}"
      jsondata = fetch_json(url)
      jd = jsondata.dig('data', 'jobBasicInfo', 'jobContent')
      salary = jsondata.dig('data', 'recruitmentData', 'salary') || ''

      pattern = %r{[\p{L}ー\d]{0,12}[：/]?\s*[\d,]{3,}\s*円}
      match = salary.match(pattern)
      salary_match = match ? match[0] : nil

      { jd: jd, salary_match: salary_match }
    end

    def scrape_company_info(company_id)
      url = "https://careerforum.net/api/public/companies/#{company_id}?eventId=-1"
      jsondata = fetch_json(url)
      jsondata.dig('data', 'appeal')
    end

    (1..12).each do |page|
      # url = "https://careerforum.net/api/public/companies?eventId=-1&jobTitleCategoryList=101&industryCategoryList=3&pageNum=#{page}&pageSize=20"
      url = "https://careerforum.net/api/public/companies?jobTitleCategoryList=101&industryCategoryList=3&pageNum=#{page}&pageSize=20"
      jsondata = fetch_json(url)

      jsondata.dig('data', 'companyList').each do |job|
        jobs = []
        company_name = job['dispCompNameEn']
        logo_string = job['logoUrl'].split('?', 2).first
        # industry_name = job['businessContent']

        job['jobList'].each do |j|
          company_id = j['companyId']
          job_id = j['jobId']

          jd_data = scrape_jd(job_id)

          jobs << {
            company_name: company_name,
            company_info: scrape_company_info(company_id),
            logo_link: logo_string,
            job_name: j['jobName'],
            deadline: j['entryEndedAt'],
            jd: jd_data[:jd],
            job_url: "https://careerforum.net/en/event/bos/companylist_792/#{company_id}/#{job_id}",
            source_url: "https://careerforum.net/en/event/bos/companylist_792/#{company_id}/#{job_id}",
            internship: j['isInternship'],
            location: 'Tokyo',
            salary: jd_data[:salary_match]
          }
        end

        jobs.each do |data|
          company = Company.find_or_create_by(name: data[:company_name])
          company.update(
            description: data[:company_info]
          )
          begin
            logo = URI.parse(data[:logo_link]).open
            company.logo.attach(io: logo, filename: "logo.png", content_type: "image/png") unless company.logo.attached?
          rescue StandardError
            # skip logo if it cannot be opened
          end

          job_opening = JobOpening.find_or_create_by(title: data[:job_name])
          job_opening.update(
            company: company,
            deadline: data[:deadline].nil? ? "N/A" : Date.parse(data[:deadline]),
            content: data[:jd],
            job_url: data[:job_url],
            location: data[:location],
            salary: data[:salary].nil? ? "N/A" : data[:salary],
            source_url: data[:job_url],
            employment_type: data[:internship] ? "Internship" : "Fulltime",
            source: "CFN"
          )
          job_opening.closed = job_opening.deadline.is_a?(Date) && Date.current > job_opening.deadline
          job_opening.save
        end
      end
    end
  end
end
