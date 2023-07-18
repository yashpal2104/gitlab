# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PushAccessLevel'] do
  subject { described_class }

  let(:fields) { %i[access_level access_level_description user group deploy_key] }

  specify { is_expected.to have_graphql_fields(fields).only }
end
