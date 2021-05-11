# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BoardsHelper do
  let_it_be(:project) { create(:project) }
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:project_board) { create(:board, project: project) }

  describe '#board_list_data' do
    let(:results) { helper.board_list_data }

    it 'contains an endpoint to get users list' do
      assign(:board, project_board)
      assign(:project, project)

      expect(results).to include(list_assignees_path: "/-/boards/#{project_board.id}/users.json")
    end
  end

  describe '#current_board_json' do
    let(:board_json) { helper.current_board_json }
    let(:label1) { create(:label, name: "feijoa") }
    let(:label2) { create(:label, name: "pineapple") }
    let(:milestone) { create(:milestone) }

    it 'serializes with child object attributes' do
      board = create(:board, project: project, milestone: milestone, assignee: user, labels: [label1, label2])
      assign(:board, board)

      expect(board_json).to match_schema('current-board', dir: 'ee')
    end
  end

  describe '#board_base_url' do
    context 'when epic board' do
      let_it_be(:epic_board) { create(:epic_board, group: group) }

      it 'generates the correct url' do
        assign(:board, epic_board)
        assign(:group, group)

        expect(helper.board_base_url).to eq "http://test.host/groups/#{group.full_path}/-/epic_boards"
      end
    end
  end

  describe '#board_data' do
    let(:board_data) { helper.board_data }

    before do
      allow(helper).to receive(:current_user) { user }
    end

    context 'issue board' do
      before do
        assign(:board, project_board)
        assign(:project, project)

        allow(helper).to receive(:can?).with(user, :create_non_backlog_issues, project_board).and_return(true)
        allow(helper).to receive(:can?).with(user, :admin_issue, project_board).and_return(true)
        allow(helper).to receive(:can?).with(user, :admin_issue_board_list, project).and_return(false)
      end

      shared_examples 'serializes the availability of a licensed feature' do |feature_name, feature_key|
        context "when '#{feature_name}' is available" do
          before do
            stub_licensed_features({ feature_name => true })
          end

          it "indicates that the feature is available in a boolean string" do
            expect(board_data[feature_key]).to eq("true")
          end
        end

        context "when '#{feature_name}' is unavailable" do
          before do
            stub_licensed_features({ feature_name => false })
          end

          it "indicates that the feature is unavailable in a boolean string" do
            expect(board_data[feature_key]).to eq("false")
          end
        end
      end

      context 'when no iteration', :aggregate_failures do
        it 'serializes board without iteration' do
          expect(board_data[:board_iteration_title]).to be_nil
          expect(board_data[:board_iteration_id]).to be_nil
        end
      end

      context 'when board is scoped to an iteration' do
        let_it_be(:iteration) { create(:iteration, group: group) }

        before do
          project_board.update!(iteration: iteration)
        end

        it 'serializes board with iteration' do
          expect(board_data[:board_iteration_title]).to eq(iteration.title)
          expect(board_data[:board_iteration_id]).to eq(iteration.id)
        end
      end

      [[:multiple_issue_assignees, :multiple_assignees_feature_available],
       [:issue_weights, :weight_feature_available],
       [:board_milestone_lists, :milestone_lists_available],
       [:board_assignee_lists, :assignee_lists_available],
       [:board_iteration_lists, :iteration_lists_available],
       [:epics, :epic_feature_available],
       [:iterations, :iteration_feature_available],
       [:scoped_labels, :scoped_labels]].each do |feature_name, feature_key|
        include_examples "serializes the availability of a licensed feature", feature_name, feature_key
      end
    end

    context 'epic board' do
      let_it_be(:epic_board) { create(:epic_board, group: group) }

      before do
        assign(:board, epic_board)
        assign(:group, group)

        allow(helper).to receive(:can?).with(user, :create_non_backlog_issues, epic_board).and_return(false)
        allow(helper).to receive(:can?).with(user, :admin_epic, epic_board).and_return(true)
        allow(helper).to receive(:can?).with(user, :admin_epic_board_list, group).and_return(true)

        allow(helper).to receive(:can?).with(user, :admin_issue, group).and_return(false)
        allow(helper).to receive(:can?).with(user, :admin_issue_board_list, group).and_return(false)
      end

      it 'returns the correct permission for updating the board' do
        expect(board_data[:can_update]).to eq "true"
      end

      it 'returns the correct permission for administering the boards lists' do
        expect(board_data[:can_admin_list]).to eq "true"
      end
    end
  end
end
