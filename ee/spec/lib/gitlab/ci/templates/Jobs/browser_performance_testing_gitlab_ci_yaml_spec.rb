# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Jobs/Browser-Performance-Testing.gitlab-ci.yml' do
  subject(:template) do
    <<~YAML
      stages:
        - test
        - performance

      include:
        - template: 'Jobs/Browser-Performance-Testing.gitlab-ci.yml'

      placeholder:
        script:
          - keep pipeline validator happy by having a job when stages are intentionally empty
    YAML
  end

  describe 'the created pipeline' do
    let_it_be(:project_with_ci_kubernetes_active) do
      create(:project, :repository, variables: [
        build(:ci_variable, key: 'CI_KUBERNETES_ACTIVE', value: 'true')
      ])
    end

    let(:project) { project_with_ci_kubernetes_active }
    let(:user) { project.first_owner }
    let(:default_branch) { 'master' }
    let(:pipeline_ref) { default_branch }
    let(:service) { Ci::CreatePipelineService.new(project, user, ref: pipeline_ref) }
    let(:pipeline) { service.execute!(:push).payload }
    let(:build_names) { pipeline.builds.pluck(:name) }

    before do
      stub_ci_pipeline_yaml_file(template)
      stub_feature_flags(redirect_to_latest_template_jobs_browser_performance_testing: false)

      allow_next_instance_of(Ci::BuildScheduleWorker) do |worker|
        allow(worker).to receive(:perform).and_return(true)
      end
      allow(project).to receive(:default_branch).and_return(default_branch)
    end

    it 'has no errors' do
      expect(pipeline.errors).to be_empty
    end

    context 'when variable is KUBECONFIG and not CI_KUBERNETES_ACTIVE' do
      let_it_be(:project_with_kubeconfig) do
        create(:project, :repository, variables: [
          build(:ci_variable, key: 'KUBECONFIG', value: 'true')
        ])
      end

      it 'is present' do
        expect(build_names).to include('browser_performance')
      end
    end

    shared_examples_for 'browser_performance job on tag or branch' do
      it 'by default' do
        expect(build_names).to include('browser_performance')
      end

      it 'when BROWSER_PERFORMANCE_DISABLED' do
        create(:ci_variable, project: project, key: 'BROWSER_PERFORMANCE_DISABLED', value: '1')

        expect(build_names).not_to include('browser_performance')
      end
    end

    context 'on master' do
      it_behaves_like 'browser_performance job on tag or branch'
    end

    context 'on another branch' do
      let(:pipeline_ref) { 'feature' }

      it_behaves_like 'browser_performance job on tag or branch'
    end

    context 'on tag' do
      let(:pipeline_ref) { 'v1.0.0' }

      it_behaves_like 'browser_performance job on tag or branch'
    end

    context 'on merge request' do
      let(:service) { MergeRequests::CreatePipelineService.new(project: project, current_user: user) }
      let(:merge_request) { create(:merge_request, :simple, source_project: project) }
      let(:pipeline) { service.execute(merge_request).payload }

      it 'has no jobs' do
        expect(pipeline).to be_merge_request_event
        expect(build_names).to be_empty
      end
    end
  end
end
