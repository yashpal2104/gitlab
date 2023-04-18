# frozen_string_literal: true

module Gitlab
  module Ci
    class ProjectConfig
      class Source
        include Gitlab::Utils::StrongMemoize

        def initialize(project, sha, custom_content, pipeline_source, pipeline_source_bridge, pipeline)
          @project = project
          @sha = sha
          @custom_content = custom_content
          @pipeline_source = pipeline_source
          @pipeline_source_bridge = pipeline_source_bridge
          @pipeline = pipeline
        end

        def exists?
          strong_memoize(:exists) do
            content.present?
          end
        end

        def content
          raise NotImplementedError
        end

        # Indicates if we are prepending the content with an "internal" `include`
        def internal_include_prepended?
          false
        end

        def source
          raise NotImplementedError
        end

        # Used to populate the pipeline_ref claim in Ci::JwtV2
        def url
          raise NotImplementedError
        end

        private

        attr_reader :project, :sha, :custom_content, :pipeline_source, :pipeline_source_bridge, :pipeline

        def ci_config_path
          @ci_config_path ||= project.ci_config_path_or_default
        end
      end
    end
  end
end
