# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        class IssueIdentifier < Tool
          attr_accessor :retries

          MAX_RETRIES = 3
          RESOURCE_NAME = 'issue'
          NAME = "IssueIdentifier"
          DESCRIPTION = <<-DESC
            Useful tool for when you need to identify and fetch information or ask questions about a specific issue.
            Do not use this tool if you already have the information about the issue.
          DESC

          # our template
          PROMPT_TEMPLATE = [
            Utils::Prompt.as_system(
              <<~PROMPT
                You can identify an issue or fetch information about an issue.
                An issue can be referenced by url or numeric IDs preceded by symbol.
                ResourceIdentifierType can only be one of [current, iid, url, reference]
                ResourceIdentifier can be "current", number, url

                Provide your answer in JSON form! The answer should be just the JSON without any other commentary!
                Make sure the response is a valid JSON. Follow the exact JSON format:

                ```json
                {
                  "ResourceIdentifierType": <ResourceIdentifierType>
                  "ResourceIdentifier": <ResourceIdentifier>
                }
                ```

                Example of an issue reference:
                The user question or request may include: https://some.host.name/some/long/path/-/issues/410692
                Response:
                ```json
                {
                  "ResourceIdentifierType": "url",
                  "ResourceIdentifier": "https://some.host.name/some/long/path/-/issues/410692"
                }
                ```

                Another example of an issue reference:
                The user question or request may include: #12312312
                Response:
                ```json
                {
                  "ResourceIdentifierType": "iid",
                  "ResourceIdentifier": 12312312
                }
                ```

                Third example of an issue reference:
                The user question or request may include: long/groups/path#12312312
                Response:
                ```json
                {
                  "ResourceIdentifierType": "reference",
                  "ResourceIdentifier": "long/groups/path#12312312"
                }
                ```

                Begin!
            PROMPT
            ),
            Utils::Prompt.as_user("Question: %<input>s"),
            Utils::Prompt.as_assistant("%<suggestions>s")
          ].freeze

          def initialize
            super(name: NAME, description: DESCRIPTION)
            @retries = 0
          end

          def execute(context, input_variables)
            return already_identified_answer(context) if already_identified?(input_variables)

            MAX_RETRIES.times do
              @context = context
              @input_variables = input_variables

              prompt = prompt(input_variables)
              response = request(prompt)
              json = extract_json(response)
              issue = identify_issue(json[:ResourceIdentifierType], json[:ResourceIdentifier])

              # if issue not found then return an error as the answer.
              return issue_not_found unless issue

              # now the issue in context is being referenced in user input.
              self.context.resource = issue

              content = "I now have the JSON information about the issue ##{issue.iid}."
              return Answer.new(status: :ok, context: context, content: content, tool: nil)
            rescue JSON::ParserError
              # try to help out AI to fix the JSON format by adding the error as an observation
              self.retries += 1

              error_message = "\nObservation: JSON has an invalid format. Please retry"
              input_variables[:suggestions] += error_message
            rescue StandardError
              # todo: add exception logging
              return Answer.error_answer(context: context, content: _("Unexpected error"))
            end

            issue_not_found
          end

          private

          def already_identified?(input_variables)
            identifier_action_regex = /(?=Action: IssueIdentifier)/
            json_loaded_regex = /(?=I now have the JSON information about the issue)/

            issue_identifier_calls = input_variables[:suggestions].scan(identifier_action_regex).size
            issue_identifier_json_loaded = input_variables[:suggestions].scan(json_loaded_regex).size

            issue_identifier_calls > 1 && issue_identifier_json_loaded >= 1
          end

          def extract_json(response)
            content_after_ticks = response.split(/```json/, 2).last
            content_between_ticks = content_after_ticks&.split(/```/, 2)&.first

            Gitlab::Json.parse(content_between_ticks&.strip.to_s).with_indifferent_access
          end

          def request(prompt)
            params = ::Gitlab::Llm::VertexAi::Configuration.default_payload_parameters.merge(
              temperature: 0.2
            )

            ai_client = context.ai_client
            ai_client.text(content: prompt, parameters: { **params })&.dig("predictions", 0, "content").to_s.strip
          end

          def identify_issue(resource_identifier_type, resource_identifier)
            return context.resource if current_resource?(resource_identifier, RESOURCE_NAME)

            issue = case resource_identifier_type
                    when 'iid'
                      by_iid(resource_identifier)
                    when 'url', 'reference'
                      extract_issue(resource_identifier)
                    end

            return issue if context.current_user.can?(:read_issue, issue)
          end

          def by_iid(resource_identifier)
            issues = Issue.in_projects(projects_from_context).iid_in(resource_identifier)

            return issues.first if issues.one?
          end

          def extract_issue(text)
            extractor = Gitlab::ReferenceExtractor.new(projects_from_context&.first, context.current_user)
            extractor.analyze(text, {})
            issues = extractor.issues

            return issues.first if issues.one?
          end

          def issue_not_found
            content = _("I am sorry, I am unable to find the issue you are looking for.")

            Answer.error_answer(context: context, content: content)
          end

          def prompt(input_variables)
            Utils::Prompt.no_role_text(PROMPT_TEMPLATE, input_variables)
          end

          def already_identified_answer(context)
            resource = context.resource
            content = "You already have identified the issue ##{resource.iid}, read carefully."

            ::Gitlab::Llm::Chain::Answer.new(
              status: :ok, context: context, content: content, tool: nil, is_final: false
            )
          end
        end
      end
    end
  end
end
