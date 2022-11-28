# frozen_string_literal: true

RSpec.shared_examples 'it runs batched background migration jobs' do |tracking_database, table_name|
  include ExclusiveLeaseHelpers

  describe 'defining the job attributes' do
    it 'defines the data_consistency as always' do
      expect(described_class.get_data_consistency).to eq(:always)
    end

    it 'defines the feature_category as database' do
      expect(described_class.get_feature_category).to eq(:database)
    end

    it 'defines the idempotency as true' do
      expect(described_class.idempotent?).to be_truthy
    end
  end

  describe '.tracking_database' do
    it 'does not raise an error' do
      expect { described_class.tracking_database }.not_to raise_error
    end

    it 'overrides the method to return the tracking database' do
      expect(described_class.tracking_database).to eq(tracking_database)
    end
  end

  describe '.lease_key' do
    let(:lease_key) { described_class.name.demodulize.underscore }

    it 'does not raise an error' do
      expect { described_class.lease_key }.not_to raise_error
    end

    it 'returns the lease key' do
      expect(described_class.lease_key).to eq(lease_key)
    end
  end

  describe '.enabled?' do
    it 'returns true when execute_batched_migrations_on_schedule feature flag is enabled' do
      stub_feature_flags(execute_batched_migrations_on_schedule: true)

      expect(described_class.enabled?).to be_truthy
    end

    it 'returns false when execute_batched_migrations_on_schedule feature flag is disabled' do
      stub_feature_flags(execute_batched_migrations_on_schedule: false)

      expect(described_class.enabled?).to be_falsey
    end
  end

  describe '#perform' do
    subject(:worker) { described_class.new }

    context 'when the base model does not exist' do
      before do
        if Gitlab::Database.has_config?(tracking_database)
          skip "because the base model for #{tracking_database} exists"
        end
      end

      it 'does nothing' do
        expect(worker).not_to receive(:active_migration)
        expect(worker).not_to receive(:run_active_migration)

        expect { worker.perform }.not_to raise_error
      end

      it 'logs a message indicating execution is skipped' do
        expect(Sidekiq.logger).to receive(:info) do |payload|
          expect(payload[:class]).to eq(described_class.name)
          expect(payload[:database]).to eq(tracking_database)
          expect(payload[:message]).to match(/skipping migration execution/)
        end

        expect { worker.perform }.not_to raise_error
      end
    end

    context 'when the base model does exist' do
      before do
        unless Gitlab::Database.has_config?(tracking_database)
          skip "because the base model for #{tracking_database} does not exist"
        end
      end

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(execute_batched_migrations_on_schedule: false)
        end

        it 'does nothing' do
          expect(worker).not_to receive(:active_migration)
          expect(worker).not_to receive(:run_active_migration)

          worker.perform
        end
      end

      context 'when the feature flag is enabled' do
        let(:base_model) { Gitlab::Database.database_base_models[tracking_database] }

        before do
          stub_feature_flags(execute_batched_migrations_on_schedule: true)

          allow(Gitlab::Database::BackgroundMigration::BatchedMigration).to receive(:active_migration)
            .with(connection: base_model.connection)
            .and_return(nil)
        end

        context 'when database config is shared' do
          it 'does nothing' do
            expect(Gitlab::Database).to receive(:db_config_share_with)
              .with(base_model.connection_db_config).and_return('main')

            expect(worker).not_to receive(:active_migration)
            expect(worker).not_to receive(:run_active_migration)

            worker.perform
          end
        end

        context 'when no active migrations exist' do
          it 'does nothing' do
            expect(worker).not_to receive(:run_active_migration)

            worker.perform
          end
        end

        context 'when active migrations exist' do
          let(:job_interval) { 5.minutes }
          let(:lease_timeout) { 15.minutes }
          let(:lease_key) { described_class.name.demodulize.underscore }
          let(:interval_variance) { described_class::INTERVAL_VARIANCE }
          let(:migration_id) { 123 }
          let(:migration) do
            build(
              :batched_background_migration, :active,
              id: migration_id, interval: job_interval, table_name: table_name
            )
          end

          let(:execution_worker_class) do
            case tracking_database
            when :main
              Database::BatchedBackgroundMigration::MainExecutionWorker
            when :ci
              Database::BatchedBackgroundMigration::CiExecutionWorker
            end
          end

          before do
            allow(Gitlab::Database::BackgroundMigration::BatchedMigration).to receive(:active_migration)
              .with(connection: base_model.connection)
              .and_return(migration)

            allow(migration).to receive(:interval_elapsed?).with(variance: interval_variance).and_return(true)
            allow(migration).to receive(:reload)
          end

          context 'when the calculated timeout is less than the minimum allowed' do
            let(:minimum_timeout) { described_class::MINIMUM_LEASE_TIMEOUT }
            let(:job_interval) { 2.minutes }

            it 'sets the lease timeout to the minimum value' do
              expect_to_obtain_exclusive_lease(lease_key, timeout: minimum_timeout)

              expect_next_instance_of(execution_worker_class) do |worker|
                expect(worker).to receive(:perform).with(tracking_database, migration_id)
              end

              expect(worker).to receive(:run_active_migration).and_call_original

              worker.perform
            end
          end

          it 'always cleans up the exclusive lease' do
            lease = stub_exclusive_lease_taken(lease_key, timeout: lease_timeout)

            expect(lease).to receive(:try_obtain).and_return(true)

            expect(worker).to receive(:run_active_migration).and_raise(RuntimeError, 'I broke')
            expect(lease).to receive(:cancel)

            expect { worker.perform }.to raise_error(RuntimeError, 'I broke')
          end

          it 'delegetes the execution to ExecutionWorker' do
            base_model = Gitlab::Database.database_base_models[tracking_database]

            expect(Gitlab::Database::SharedModel).to receive(:using_connection).with(base_model.connection).and_yield
            expect_next_instance_of(execution_worker_class) do |worker|
              expect(worker).to receive(:perform).with(tracking_database, migration_id)
            end

            worker.perform
          end
        end
      end
    end
  end

  describe 'executing an entire migration', :freeze_time, if: Gitlab::Database.has_config?(tracking_database) do
    include Gitlab::Database::DynamicModelHelpers
    include Database::DatabaseHelpers

    let(:migration_class) do
      Class.new(Gitlab::BackgroundMigration::BatchedMigrationJob) do
        job_arguments :matching_status
        operation_name :update_all

        def perform
          each_sub_batch(
            batching_scope: -> (relation) { relation.where(status: matching_status) }
          ) do |sub_batch|
            sub_batch.update_all(some_column: 0)
          end
        end
      end
    end

    let(:gitlab_schema) { "gitlab_#{tracking_database}" }
    let!(:migration) do
      create(
        :batched_background_migration,
        :active,
        table_name: new_table_name,
        column_name: :id,
        max_value: migration_records,
        batch_size: batch_size,
        sub_batch_size: sub_batch_size,
        job_class_name: 'ExampleDataMigration',
        job_arguments: [1],
        gitlab_schema: gitlab_schema
      )
    end

    let(:base_model) { Gitlab::Database.database_base_models[tracking_database] }
    let(:new_table_name) { '_test_example_data' }
    let(:batch_size) { 5 }
    let(:sub_batch_size) { 2 }
    let(:number_of_batches) { 10 }
    let(:migration_records) { batch_size * number_of_batches }

    let(:connection) { Gitlab::Database.database_base_models[tracking_database].connection }
    let(:example_data) { define_batchable_model(new_table_name, connection: connection) }

    around do |example|
      Gitlab::Database::SharedModel.using_connection(connection) do
        example.run
      end
    end

    before do
      # Create example table populated with test data to migrate.
      #
      # Test data should have two records that won't be updated:
      #   - one record beyond the migration's range
      #   - one record that doesn't match the migration job's batch condition
      connection.execute(<<~SQL)
        CREATE TABLE #{new_table_name} (
          id integer primary key,
          some_column integer,
          status smallint);

        INSERT INTO #{new_table_name} (id, some_column, status)
        SELECT generate_series, generate_series, 1
        FROM generate_series(1, #{migration_records + 1});

        UPDATE #{new_table_name}
          SET status = 0
        WHERE some_column = #{migration_records - 5};
      SQL

      stub_feature_flags(execute_batched_migrations_on_schedule: true)

      stub_const('Gitlab::BackgroundMigration::ExampleDataMigration', migration_class)
    end

    subject(:full_migration_run) do
      # process all batches, then do an extra execution to mark the job as finished
      (number_of_batches + 1).times do
        described_class.new.perform

        travel_to((migration.interval + described_class::INTERVAL_VARIANCE).seconds.from_now)
      end
    end

    it 'marks the migration record as finished' do
      expect { full_migration_run }.to change { migration.reload.status }.from(1).to(3) # active -> finished
    end

    it 'creates job records for each processed batch', :aggregate_failures do
      expect { full_migration_run }.to change { migration.reload.batched_jobs.count }.from(0)

      final_min_value = migration.batched_jobs.reduce(1) do |next_min_value, batched_job|
        expect(batched_job.min_value).to eq(next_min_value)

        batched_job.max_value + 1
      end

      final_max_value = final_min_value - 1
      expect(final_max_value).to eq(migration_records)
    end

    it 'marks all job records as succeeded', :aggregate_failures do
      expect { full_migration_run }.to change { migration.reload.batched_jobs.count }.from(0)

      expect(migration.batched_jobs).to all(be_succeeded)
    end

    it 'updates matching records in the range', :aggregate_failures do
      expect { full_migration_run }
        .to change { example_data.where('status = 1 AND some_column <> 0').count }
        .from(migration_records).to(1)

      record_outside_range = example_data.last

      expect(record_outside_range.status).to eq(1)
      expect(record_outside_range.some_column).not_to eq(0)
    end

    it 'does not update non-matching records in the range' do
      expect { full_migration_run }.not_to change { example_data.where('status <> 1 AND some_column <> 0').count }
    end

    context 'health status' do
      subject(:migration_run) { described_class.new.perform }

      it 'puts migration on hold when there is autovaccum activity on related tables' do
        swapout_view_for_table(:postgres_autovacuum_activity, connection: connection)
        create(
          :postgres_autovacuum_activity,
          table: migration.table_name,
          table_identifier: "public.#{migration.table_name}"
        )

        expect { migration_run }.to change { migration.reload.on_hold? }.from(false).to(true)
      end

      it 'puts migration on hold when the pending WAL count is above the limit' do
        sql = Gitlab::Database::BackgroundMigration::HealthStatus::Indicators::WriteAheadLog::PENDING_WAL_COUNT_SQL
        limit = Gitlab::Database::BackgroundMigration::HealthStatus::Indicators::WriteAheadLog::LIMIT

        expect(connection).to receive(:execute).with(sql).and_return([{ 'pending_wal_count' => limit + 1 }])

        expect { migration_run }.to change { migration.reload.on_hold? }.from(false).to(true)
      end
    end
  end
end
