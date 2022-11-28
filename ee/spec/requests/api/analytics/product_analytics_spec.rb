# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Analytics::ProductAnalytics do
  let_it_be(:project) { create(:project) }

  let(:current_user) { project.owner }
  let(:cube_api_load_url) { "http://cube.dev/cubejs-api/v1/load" }
  let(:cube_api_dry_run_url) { "http://cube.dev/cubejs-api/v1/dry-run" }
  let(:cube_api_meta_url) { "http://cube.dev/cubejs-api/v1/meta" }
  let(:query) { { query: { measures: ['Jitsu.count'] }, 'queryType': 'multi' } }

  let(:request_meta) { post api("/projects/#{project.id}/product_analytics/request/meta", current_user) }

  shared_examples 'a not found error' do
    it 'load returns a 404' do
      request_load(false)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'dry-run returns a 404' do
      request_load(true)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'meta returns a 404' do
      request_meta

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  shared_examples 'does basics of a cube query' do |is_dry_run: false|
    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(cube_api_proxy: false)
      end

      it 'returns a 404' do
        request_load(is_dry_run)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when feature is unlicensed' do
      before do
        stub_licensed_features(product_analytics: false)
      end

      it_behaves_like 'a not found error'
    end

    context 'when current user has guest project access' do
      let_it_be(:current_user) { create(:user) }

      before do
        project.add_guest(current_user)
      end

      it 'returns an unauthorized error' do
        request_load(is_dry_run)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when current user is a project developer' do
      let_it_be(:current_user) { create(:user) }

      before do
        project.add_developer(current_user)
      end

      it 'returns a 200' do
        request_load(is_dry_run)

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when query param is missing' do
        let(:query) { { 'queryType': 'multi' } }

        it 'returns a 400' do
          request_load(is_dry_run)

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when a query param is unsupported' do
        let(:query) { { query: { measures: ['Jitsu.count'] }, 'queryType': 'multi', 'badParam': 1 } }

        it 'ignores the unsupported param' do
          request_load(is_dry_run)

          expect(WebMock).to have_requested(:post, is_dry_run ? cube_api_dry_run_url : cube_api_load_url).with(
            body: { query: { measures: ['Jitsu.count'] }, 'queryType': 'multi' }
          )

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'when cube_api_base_url application setting is not set' do
      before do
        stub_ee_application_setting(cube_api_base_url: nil)
      end

      it_behaves_like 'a not found error'
    end

    context 'when cube_api_key application setting is not set' do
      before do
        stub_ee_application_setting(cube_api_key: nil)
      end

      it_behaves_like 'a not found error'
    end

    context 'when enable_product_analytics application setting is false' do
      before do
        stub_ee_application_setting(product_analytics_enabled: false)
      end

      it 'returns a 404' do
        request_load(is_dry_run)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'POST projects/:id/product_analytics/request/load' do
    before do
      stub_cube_load
      stub_cube_proxy_setup
    end

    it_behaves_like 'does basics of a cube query', is_dry_run: false
  end

  describe 'POST projects/:id/product_analytics/request/dry-run' do
    before do
      stub_cube_dry_run
      stub_cube_proxy_setup
    end

    it_behaves_like 'does basics of a cube query', is_dry_run: true
  end

  describe 'POST projects/:id/product_analytics/request/meta' do
    before do
      stub_cube_meta
      stub_cube_proxy_setup
    end

    context 'when current user has guest project access' do
      let_it_be(:current_user) { create(:user) }

      before do
        project.add_guest(current_user)
      end

      it 'returns an unauthorized error' do
        request_meta

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when current user is a project developer' do
      let_it_be(:current_user) { create(:user) }

      before do
        project.add_developer(current_user)
      end

      it 'returns a 200' do
        request_meta

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  private

  def request_load(is_dry_run)
    post api("/projects/#{project.id}/product_analytics/request/#{is_dry_run ? 'dry-run' : 'load'}", current_user),
    params: query
  end

  def stub_cube_proxy_setup
    stub_licensed_features(product_analytics: true)
    stub_ee_application_setting(product_analytics_enabled: true)
    stub_ee_application_setting(cube_api_key: 'testtest')
    stub_ee_application_setting(cube_api_base_url: 'http://cube.dev')
  end

  def stub_cube_load
    stub_request(:post, cube_api_load_url)
      .to_return(status: 201, body: "{}", headers: {})
  end

  def stub_cube_dry_run
    stub_request(:post, cube_api_dry_run_url)
      .to_return(status: 201, body: "{}", headers: {})
  end

  def stub_cube_meta
    stub_request(:get, cube_api_meta_url)
      .to_return(status: 201, body: "{}", headers: {})
  end
end
