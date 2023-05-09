# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::ProjectService, '#visibility', feature_category: :global_search do
  include SearchResultHelpers
  include ProjectHelpers
  include UserHelpers

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'visibility', :elastic_delete_by_query, :sidekiq_inline do
    include_context 'ProjectPolicyTable context'
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, :repository, namespace: group) }
    let_it_be_with_reload(:project2) { create(:project, :repository) }

    let(:user) { create_user_from_membership(project, membership) }
    let(:projects) { [project, project2] }
    let(:search_level) { project }

    where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
      permission_table_for_guest_feature_access_and_non_private_project_only
    end

    with_them do
      before do
        project.repository.index_commits_and_blobs
        project2.repository.index_commits_and_blobs
      end

      it_behaves_like 'search respects visibility' do
        let(:scope) { 'commits' }
        let(:search) { 'initial' }
      end

      it_behaves_like 'search respects visibility' do
        let(:scope) { 'blobs' }
        let(:search) { '.gitmodules' }
      end

      context 'when backfill_traversal_ids_to_blobs_and_wiki_blobs migration has not been completed' do
        before do
          set_elasticsearch_migration_to(:backfill_traversal_ids_to_blobs_and_wiki_blobs, including: false)
        end

        it_behaves_like 'search respects visibility' do
          let(:scope) { 'blobs' }
          let(:search) { '.gitmodules' }
        end
      end
    end
  end
end
