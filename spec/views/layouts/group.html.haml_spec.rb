# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'layouts/group', feature_category: :subgroups do
  let_it_be(:group) { create(:group) } # rubocop:todo RSpec/FactoryBot/AvoidCreate
  let(:invite_member) { true }

  before do
    allow(view).to receive(:can_admin_group_member?).and_return(invite_member)
    assign(:group, group)
    allow(view).to receive(:current_user_mode).and_return(Gitlab::Auth::CurrentUserMode.new(build_stubbed(:user)))
  end

  subject do
    render

    rendered
  end

  context 'with ability to invite members' do
    it { is_expected.to have_selector('.js-invite-members-modal') }
  end

  context 'without ability to invite members' do
    let(:invite_member) { false }

    it { is_expected.not_to have_selector('.js-invite-members-modal') }
  end
end
