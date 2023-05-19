# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Agents
        class ZeroShot
          attr_reader :tools, :user_input, :context
          attr_accessor :iterations

          MAX_ITERATIONS = 10

          def initialize(user_input:, tools:, context:)
            @user_input = user_input
            @tools = tools
            @context = context
            @iterations = 0
          end

          PROMPT_TEMPLATE = [
            Utils::PromptRoles.system(
              <<~PROMPT
                Answer the following questions as best you can. Start with identifying the resource first.
                You have access to the following tools:
                %<tools_definitions>
                Use the following format:
                Question: the input question you must answer
                Thought: you should always think about what to do
                Action: the action to take, should be one from this list: %<tool_names>
                Action Input: the input to the action
                Observation: the result of the action

                ... (this Thought/Action/Action Input/Observation sequence can repeat N times)

                Thought: I know the final answer
                Final Answer: the final answer to the original input question
                Remember to start a line with "Final Answer:" to give me the final answer.

                Begin!
              PROMPT
            ),
            Utils::PromptRoles.user("Question: %<user_input>s"),
            Utils::PromptRoles.assistant("%<agent_scratchpad>s", "Thought: ")
          ].freeze

          def execute
            MAX_ITERATIONS.times do
              response = request(prompt)
              answer = Answer.from_response(response_body: response, tools: tools, context: context)

              return answer if answer.is_final?

              input_variables[:agent_scratchpad] = input_variables[:agent_scratchpad].to_s + answer.content.to_s
              tool = answer.tool

              tool_answer = tool.execute(
                context,
                {
                  input: user_input,
                  suggestions: "#{answer.content}\n#{answer.suggestions&.join("\n")}"
                }
              )

              return tool_answer if tool_answer.is_final?

              input_variables[:agent_scratchpad] += "Observation: #{tool_answer.content}\n"
            end

            Answer.final_answer(context: context, content: Answer.default_final_answer)
          end

          private

          def prompt
            prompt = PROMPT_TEMPLATE.map(&:last).join

            format(prompt.to_s, input_variables)
          end

          def request(prompt)
            context.client.text(content: prompt)&.dig("predictions", 0, 'candidates', 0, 'content').to_s.strip
          end

          def input_variables
            @input_variables ||= {
              tool_names: tools.map(&:name),
              tools_definitions: tools.map { |tool| "#{tool.name}: #{tool.description}" }.to_s,
              user_input: user_input,
              agent_scratchpad: nil
            }
          end
        end
      end
    end
  end
end
