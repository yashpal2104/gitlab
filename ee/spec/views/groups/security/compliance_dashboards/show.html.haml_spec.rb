# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "groups/security/compliance_dashboards/show", type: :view, feature_category: :compliance_management do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:group) { build_stubbed(:group) }
  let(:framework_csv_export_path) { group_security_compliance_framework_reports_path(group, format: :csv) }
  let(:merge_commits_csv_export_path) { group_security_merge_commit_reports_path(group) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(:group, group)
  end

  it 'renders with the correct data attributes', :aggregate_failures do
    render

    expect(rendered).to have_selector('#js-compliance-report')
    expect(rendered).to have_selector("[data-can-add-edit='true']")
    expect(rendered).to have_selector("[data-frameworks-csv-export-path='#{framework_csv_export_path}']")
    expect(rendered).to have_selector("[data-merge-commits-csv-export-path='#{merge_commits_csv_export_path}']")
    expect(rendered).to have_selector("[data-group-path='#{group.full_path}']")
    expect(rendered).to have_selector("[data-root-ancestor-path='#{group.root_ancestor.full_path}']")
    expect(rendered).to have_selector("[data-base-path='#{group_security_compliance_dashboard_path(group)}']")
    expect(rendered).to have_selector("[data-pipeline-configuration-enabled='false']")
  end

  context 'for `adherence-report-ui-enabled` selector' do
    before do
      Feature.disable(:adherence_report_ui)
    end

    context 'when feature `adherence_report_ui` is not enabled' do
      it 'renders with the correct selector value' do
        render

        expect(rendered).to have_selector("[data-adherence-report-ui-enabled='false']")
      end
    end

    context 'when feature `adherence_report_ui` is enabled for a group' do
      before do
        Feature.enable(:adherence_report_ui, group)
      end

      it 'renders with the correct selector value' do
        render

        expect(rendered).to have_selector("[data-adherence-report-ui-enabled='true']")
      end
    end

    context 'when feature `adherence_report_ui` is globally enabled' do
      before do
        Feature.enable(:adherence_report_ui)
      end

      it 'renders with the correct selector value' do
        render

        expect(rendered).to have_selector("[data-adherence-report-ui-enabled='true']")
      end
    end
  end
end
