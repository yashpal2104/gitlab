# frozen_string_literal: true

module QA
  RSpec.describe 'Plan', :requires_admin, product_group: :optimize, only: { subdomain: :staging } do
    shared_examples "dora metrics api endpoint" do |expectation|
      def metric(metric)
        resource.dora_metrics(metric: metric, interval: "monthly", start_date: "2023-07-01", end_date: "2023-07-24")
      end

      it "returns correct metrics", :aggregate_failures do
        lead_time = metric("lead_time_for_changes")
        deployment_frequency = metric("deployment_frequency")

        expect(lead_time).to match_array(expectation[:lead_time])
        expect(deployment_frequency).to match_array(expectation[:deployment_frequency])
      end
    end

    describe 'Dora Metrics' do
      let(:admin_api_client) { Runtime::API::Client.as_admin }

      let(:group) do
        Resource::Sandbox.init do |resource|
          resource.api_client = admin_api_client
          resource.path = "optimize-vsa-test"
        end.reload!
      end

      context "with group metrics", testcase: "https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/419615" do
        let(:resource) { group }

        it_behaves_like "dora metrics api endpoint", {
          lead_time: [{ date: "2023-07-01", value: 509930.5 }],
          deployment_frequency: [{ date: "2023-07-01", value: 0.17 }]
        }
      end

      context "with project metrics", testcase: "https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/419616" do
        let(:resource) { project }

        let(:project) do
          Resource::Project.init do |resource|
            resource.add_name_uuid = false
            resource.api_client = admin_api_client
            resource.group = group
            resource.path = "optimize-sandbox"
            resource.name = "optimize-sandbox"
          end.reload!
        end

        it_behaves_like "dora metrics api endpoint", {
          lead_time: [{ date: "2023-07-01", value: 509930.5 }],
          deployment_frequency: [{ date: "2023-07-01", value: 0.17 }]
        }
      end
    end
  end
end
