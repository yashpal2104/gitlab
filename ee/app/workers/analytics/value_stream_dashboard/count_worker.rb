# frozen_string_literal: true

module Analytics
  module ValueStreamDashboard
    class CountWorker
      include ApplicationWorker

      # rubocop:disable Scalability/CronWorkerContext
      # This worker does not perform work scoped to a context
      include CronjobQueue
      # rubocop:enable Scalability/CronWorkerContext

      idempotent!

      data_consistency :sticky
      feature_category :value_stream_management

      CACHE_KEY = 'value_stream_dasboard_count_cursor'
      CUTOFF_DAYS = 5

      def perform
        return unless should_perform?

        runtime_limiter = Analytics::CycleAnalytics::RuntimeLimiter.new

        batch = Analytics::ValueStreamDashboard::Aggregation.load_batch
        return if batch.empty?

        batch.each do |aggregation|
          Analytics::ValueStreamDashboard::CountService.new(
            aggregation: aggregation,
            cursor: {}
          ).execute

          aggregation.update!(last_run_at: Time.current)

          break if runtime_limiter.over_time?
        end
      end

      private

      def should_perform?
        Time.current.day >= (Time.current.end_of_month.day - CUTOFF_DAYS) &&
          License.feature_available?(:group_level_analytics_dashboard)
      end
    end
  end
end
