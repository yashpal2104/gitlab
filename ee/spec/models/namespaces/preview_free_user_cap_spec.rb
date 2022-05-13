# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::PreviewFreeUserCap, :saas do
  let_it_be(:namespace, reload: true) { create(:group_with_plan, plan: :free_plan) }

  let(:should_check_namespace_plan) { true }

  before do
    stub_ee_application_setting(should_check_namespace_plan: should_check_namespace_plan)
  end

  describe '#over_limit?' do
    let(:free_plan_members_count) { described_class::FREE_USER_LIMIT + 1 }

    subject(:over_limit?) { described_class.new(namespace).over_limit? }

    before do
      stub_ee_application_setting(should_check_namespace_plan: should_check_namespace_plan)
      allow(namespace).to receive(:free_plan_members_count).and_return(free_plan_members_count)
    end

    context 'when :preview_free_user_cap is disabled' do
      before do
        stub_feature_flags(preview_free_user_cap: false)
      end

      it { is_expected.to be false }
    end

    context 'when :preview_free_user_cap is enabled' do
      before do
        stub_feature_flags(preview_free_user_cap: true)
      end

      context 'when under the number of free users limit' do
        let(:free_plan_members_count) { described_class::FREE_USER_LIMIT - 1 }

        it { is_expected.to be false }
      end

      context 'when at the same number as the free users limit' do
        let(:free_plan_members_count) { described_class::FREE_USER_LIMIT }

        it { is_expected.to be false }
      end

      context 'when over the number of free users limit' do
        context 'when it is a free plan' do
          it { is_expected.to be true }

          context 'when the namespace is not a group' do
            let_it_be(:namespace) do
              namespace = create(:user).namespace
              create(:gitlab_subscription, hosted_plan: create(:free_plan), namespace: namespace)
              namespace
            end

            it { is_expected.to be true }
          end
        end

        context 'when it is a non free plan' do
          let_it_be(:namespace) { create(:group_with_plan, plan: :ultimate_plan) }

          it { is_expected.to be false }
        end

        context 'when no plan exists' do
          let_it_be(:namespace) { create(:group) }

          it { is_expected.to be true }
        end

        context 'when should check namespace plan is false' do
          let(:should_check_namespace_plan) { false }

          it { is_expected.to be false }
        end

        context 'when excluded from free user cap' do
          before do
            namespace.namespace_settings.update_column(:exclude_from_free_user_cap, true)
          end

          it { is_expected.to be false }
        end
      end
    end
  end
end
