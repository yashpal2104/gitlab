# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Groups::SuperSidebarMenus::AnalyzeMenu, feature_category: :navigation do
  subject { described_class.new({}) }

  let(:items) { subject.instance_variable_get(:@items) }

  it 'has title and sprite_icon' do
    expect(subject.title).to eq(s_("Navigation|Analyze"))
    expect(subject.sprite_icon).to eq("chart")
  end

  it 'defines list of NilMenuItem placeholders' do
    expect(items.map(&:class).uniq).to eq([Sidebars::NilMenuItem])
    expect(items.map(&:item_id)).to eq([
      :analytics_dashboards,
      :dashboards_analytics,
      :cycle_analytics,
      :ci_cd_analytics,
      :contribution_analytics,
      :devops_adoption,
      :insights,
      :issues_analytics,
      :productivity_analytics,
      :repository_analytics
    ])
  end
end
