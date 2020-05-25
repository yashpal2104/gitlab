# frozen_string_literal: true

class BuildArtifactEntity < Grape::Entity
  include RequestAwareEntity
  include GitlabRoutingHelper

  expose :name do |job|
    job.name
  end

  expose :artifacts_expired?, as: :expired
  expose :artifacts_expire_at, as: :expire_at

  expose :path do |job|
    fast_download_project_job_artifacts_path(project, job)
  end

  expose :keep_path, if: -> (*) { job.has_expiring_archive_artifacts? } do |job|
    fast_keep_project_job_artifacts_path(project, job)
  end

  expose :browse_path do |job|
    fast_browse_project_job_artifacts_path(project, job)
  end

  expose :locked, if: -> (*) { job.job_artifacts_archive.present? } do |job|
    job.job_artifacts_archive.locked?
  end

  private

  alias_method :job, :object

  def project
    job.project
  end
end
