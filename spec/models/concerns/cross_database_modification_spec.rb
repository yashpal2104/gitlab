# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CrossDatabaseModification do
  describe '.transaction' do
    def assert_no_gitlab_schema_comment(log)
      include_arg = [/gitlab_schema/] * log.size

      expect(log).not_to include(*include_arg)
    end

    context 'feature flag disabled' do
      before do
        stub_feature_flags(track_gitlab_schema_in_current_transaction: false)
      end

      it 'does not add gitlab_schema comment' do
        recorder = ActiveRecord::QueryRecorder.new do
          ApplicationRecord.transaction do
            Project.first
          end
        end

        expect(recorder.log).to include(
          /SAVEPOINT/,
          /SELECT.*FROM "projects"/,
          /RELEASE SAVEPOINT/
        )

        assert_no_gitlab_schema_comment(recorder.log)
      end
    end

    context 'feature flag is not yet setup' do
      before do
        allow(Feature::FlipperFeature).to receive(:table_exists?).and_raise(ActiveRecord::NoDatabaseError)
      end

      it 'does not add gitlab_schema comment' do
        recorder = ActiveRecord::QueryRecorder.new do
          ApplicationRecord.transaction do
            Project.first
          end
        end

        expect(recorder.log).to include(
          /SAVEPOINT/,
          /SELECT.*FROM "projects"/,
          /RELEASE SAVEPOINT/
        )

        assert_no_gitlab_schema_comment(recorder.log)
      end
    end

    it 'adds gitlab_schema to the current transaction', :aggregate_failures do
      recorder = ActiveRecord::QueryRecorder.new do
        ApplicationRecord.transaction do
          Project.first
        end
      end

      expect(recorder.log).to include(
        /SAVEPOINT.*gitlab_schema:gitlab_main/,
        /SELECT.*FROM "projects"/,
        /RELEASE SAVEPOINT.*gitlab_schema:gitlab_main/
      )

      recorder = ActiveRecord::QueryRecorder.new do
        Ci::ApplicationRecord.transaction do
          Project.first
        end
      end

      expect(recorder.log).to include(
        /SAVEPOINT.*gitlab_schema:gitlab_ci/,
        /SELECT.*FROM "projects"/,
        /RELEASE SAVEPOINT.*gitlab_schema:gitlab_ci/
      )

      recorder = ActiveRecord::QueryRecorder.new do
        Project.transaction do
          Project.first
        end
      end

      expect(recorder.log).to include(
        /SAVEPOINT.*gitlab_schema:gitlab_main/,
        /SELECT.*FROM "projects"/,
        /RELEASE SAVEPOINT.*gitlab_schema:gitlab_main/
      )

      recorder = ActiveRecord::QueryRecorder.new do
        Ci::Pipeline.transaction do
          Project.first
        end
      end

      expect(recorder.log).to include(
        /SAVEPOINT.*gitlab_schema:gitlab_ci/,
        /SELECT.*FROM "projects"/,
        /RELEASE SAVEPOINT.*gitlab_schema:gitlab_ci/
      )
    end

    it 'yields' do
      expect { |block| ApplicationRecord.transaction(&block) }.to yield_control
    end
  end
end
