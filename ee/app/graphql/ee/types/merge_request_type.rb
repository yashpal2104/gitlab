# frozen_string_literal: true

module EE
  module Types
    module MergeRequestType
      extend ActiveSupport::Concern

      prepended do
        field :approved, GraphQL::Types::Boolean,
          method: :approved?,
          null: false, calls_gitaly: true,
          description: 'Indicates if the merge request has all the required approvals. Returns true if no ' \
                       'required approvals are configured.'

        field :approvals_left, GraphQL::Types::Int,
          null: true, calls_gitaly: true,
          description: 'Number of approvals left.'

        field :approvals_required, GraphQL::Types::Int,
          null: true, description: 'Number of approvals required.'

        field :merge_trains_count, GraphQL::Types::Int,
          null: true,
          description: 'Number of merge requests in the merge train.'

        field :has_security_reports, GraphQL::Types::Boolean,
          null: false, calls_gitaly: true,
          method: :has_security_reports?,
          description: 'Indicates if the source branch has any security reports.'

        field :security_reports_up_to_date_on_target_branch, GraphQL::Types::Boolean,
          null: false, calls_gitaly: true,
          method: :security_reports_up_to_date?,
          description: 'Indicates if the target branch security reports are out of date.'

        field :approval_state, ::Types::MergeRequests::ApprovalStateType,
          null: false,
          description: 'Information relating to rules that must be satisfied to merge this merge request.'

        field :suggested_reviewers, ::Types::AppliedMl::SuggestedReviewersType,
          null: true,
          alpha: { milestone: '15.4' },
          description: 'Suggested reviewers for merge request.' \
                       ' Returns `null` if `suggested_reviewers` feature flag is disabled.' \
                       ' This flag is disabled by default and only available on GitLab.com' \
                       ' because the feature is experimental and is subject to change without notice.'

        field :diff_llm_summaries, ::Types::MergeRequests::DiffLlmSummaryType.connection_type,
          null: true,
          alpha: { milestone: '16.1' },
          description: 'Diff summaries generated by AI'

        field :merge_request_diffs, ::Types::MergeRequestDiffType.connection_type,
          null: true,
          alpha: { milestone: '16.2' },
          extras: [:lookahead],
          description: 'Diff versions of a merge request'

        field :finding_reports_comparer,
          type: ::Types::Security::FindingReportsComparerType,
          null: true,
          alpha: { milestone: '16.1' },
          description: 'Vulnerability finding reports comparison reported on the merge request.',
          resolver: ::Resolvers::SecurityReport::FindingReportsComparerResolver
      end

      def merge_trains_count
        return unless object.target_project.merge_trains_enabled?

        object.merge_train.car_count
      end

      def suggested_reviewers
        return unless object.project.can_suggest_reviewers?

        object.predictions
      end

      # rubocop:disable CodeReuse/ActiveRecord
      # Cop is disabled because we only want to call `includes` in this class.
      def merge_request_diffs(lookahead:)
        # We include `merge_request` by default because of policy check in `MergeRequestDiffType`
        # which can result to N+1.
        includes = [:merge_request]

        selects_diff_llm_summary =
          lookahead.selection(:nodes).selects?(:diff_llm_summary) ||
          lookahead.selection(:edges).selection(:node).selects?(:diff_llm_summary)

        selects_review_llm_summaries =
          lookahead.selection(:nodes).selects?(:review_llm_summaries) ||
          lookahead.selection(:edges).selection(:node).selects?(:review_llm_summaries)

        includes << [merge_request_diff_llm_summary: [:merge_request_diff, :user]] if selects_diff_llm_summary
        includes << [merge_request_review_llm_summaries: [:user, { review: [:author] }]] if selects_review_llm_summaries

        object.merge_request_diffs.includes(includes)
      end
      # rubocop:enable CodeReuse/ActiveRecord
    end
  end
end
