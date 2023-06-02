# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        class SummarizeComments < Tool
          NAME = "SummarizeComments"
          DESCRIPTION = <<-DESC
            This tool is useful when you need to create a summary of all notes, comments or discussions on a given resource.
          DESC

          def execute
            return already_summarized_answer if already_summarized?

            content = if resource.is_a?(Noteable) && resource.notes.by_humans.exists?
                        service_response = ::Llm::GenerateSummaryService.new(
                          context.current_user, resource, { sync: true }
                        ).execute

                        build_answer(resource, service_response)
                      else
                        "#{resource_name(resource)} ##{resource.iid} has no comments to be summarized."
                      end

            ::Gitlab::Llm::Chain::Answer.new(
              status: :ok, context: context, content: content, tool: nil, is_final: false
            )
          end

          private

          def build_answer(resource, service_response)
            return "#{resource_name(resource)} ##{resource.iid}: #{service_response.message}" if service_response.error?

            [
              "I know the summary of the notes, comments, discussions for the
               #{resource_name(resource)} ##{resource.iid} is the following:",
              "\"\"\"",
              (service_response.payload[:content] || service_response.payload[:errors]&.join("\n")).to_s,
              "\"\"\""
            ].join("\n")
          end

          def already_summarized_answer
            content = "You already have the summary of the notes, comments, discussions for the " \
                      "#{resource_name(resource)} ##{resource.iid} in your context, read carefully."

            ::Gitlab::Llm::Chain::Answer.new(
              status: :ok, context: context, content: content, tool: nil, is_final: false
            )
          end

          def already_summarized?
            summarize_action_regex = /(?=Action: SummarizeComments)/
            resource_summarized_regex = /(?=I know the summary of the notes, comments, discussions for the)/

            summarize_action_count = options[:suggestions]&.scan(summarize_action_regex)&.size.to_i
            resource_summarized = options[:suggestions]&.scan(resource_summarized_regex)&.size.to_i

            summarize_action_count > 1 && resource_summarized >= 1
          end

          def resource
            @resource ||= context.resource
          end

          def resource_name(resource)
            @resource_name ||= resource.to_ability_name.humanize
          end
        end
      end
    end
  end
end
