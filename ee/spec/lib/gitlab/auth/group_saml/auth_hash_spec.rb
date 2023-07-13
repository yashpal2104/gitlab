# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::GroupSaml::AuthHash do
  let(:omniauth_auth_hash) do
    OmniAuth::AuthHash.new(extra: { raw_info: OneLogin::RubySaml::Attributes.new(raw_info_attr) })
  end

  subject(:saml_auth_hash) { described_class.new(omniauth_auth_hash) }

  describe '#groups' do
    let(:raw_info_attr) { { group_attribute => %w(Developers Owners) } }

    context 'with a lowercase groups attribute' do
      let(:group_attribute) { 'groups' }

      it 'returns array of groups' do
        expect(saml_auth_hash.groups).to eq(%w(Developers Owners))
      end
    end

    context 'with a capitalized Groups attribute' do
      let(:group_attribute) { 'Groups' }

      it 'returns array of groups' do
        expect(saml_auth_hash.groups).to eq(%w(Developers Owners))
      end
    end

    context 'when no groups are present in the auth hash' do
      let(:raw_info_attr) { {} }

      it 'returns an empty array' do
        expect(saml_auth_hash.groups).to match_array([])
      end
    end
  end

  describe '#azure_group_overage_claim?' do
    context 'when the claim is not present' do
      let(:raw_info_attr) { {} }

      it 'is false' do
        expect(saml_auth_hash.azure_group_overage_claim?).to eq(false)
      end
    end

    context 'when the claim is present' do
      # The value of the claim is irrelevant, but it's still included
      # in the test response to keep tests as real-world as possible.
      # https://learn.microsoft.com/en-us/security/zero-trust/develop/configure-tokens-group-claims-app-roles#group-overages
      let(:raw_info_attr) do
        {
          'http://schemas.microsoft.com/claims/groups.link' =>
            ['https://graph.windows.net/8c750e43/users/e631c82c/getMemberObjects']
        }
      end

      it 'is true' do
        expect(saml_auth_hash.azure_group_overage_claim?).to eq(true)
      end
    end
  end

  describe 'allowed user attributes methods' do
    context 'when the attributes are presented as an array' do
      let(:raw_info_attr) { { 'can_create_group' => %w(true), 'projects_limit' => %w(20) } }

      it 'returns the proper can_create_groups value' do
        expect(saml_auth_hash.user_attributes['can_create_group']).to eq "true"
      end

      it 'returns the proper projects_limit value' do
        expect(saml_auth_hash.user_attributes['projects_limit']).to eq "20"
      end
    end

    context 'when the attributes are presented as a string' do
      let(:raw_info_attr) { { 'can_create_group' => 'false', 'projects_limit' => '20' } }

      it 'returns the proper can_create_groups value' do
        expect(saml_auth_hash.user_attributes['can_create_group']).to eq "false"
      end

      it 'returns the proper projects_limit value' do
        expect(saml_auth_hash.user_attributes['projects_limit']).to eq "20"
      end
    end

    context 'when the attributes are not present in the SAML response' do
      let(:raw_info_attr) { {} }

      it 'returns nil for can_create_group' do
        expect(saml_auth_hash.user_attributes['can_create_group']).to eq nil
      end

      it 'returns nil for can_create_groups' do
        expect(saml_auth_hash.user_attributes['projects_limit']).to eq nil
      end
    end
  end
end
