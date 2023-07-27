# frozen_string_literal: true

# == TimeTrackable concern
#
# Contains functionality related to objects that support time tracking.
#
# Used by Issue and MergeRequest.
#

module TimeTrackable
  extend ActiveSupport::Concern

  included do
    attr_reader :time_spent, :time_spent_user, :spent_at, :summary

    alias_method :time_spent?, :time_spent

    attribute :time_estimate, default: 0

    validate :check_time_estimate
    validate :check_negative_time_spent

    has_many :timelogs, dependent: :destroy, autosave: true # rubocop:disable Cop/ActiveRecordDependent
    after_initialize :set_time_estimate_default_value
  end

  # rubocop:disable Gitlab/ModuleWithInstanceVariables
  def spend_time(options)
    @time_spent = options[:duration]
    @time_spent_note_id = options[:note_id]
    @time_spent_user = User.find(options[:user_id])
    @spent_at = options[:spent_at]
    @summary = options[:summary]
    @original_total_time_spent = nil

    return if @time_spent == 0

    @timelog = if @time_spent == :reset
                 reset_spent_time
               else
                 add_or_subtract_spent_time
               end
  end
  alias_method :spend_time=, :spend_time
  # rubocop:enable Gitlab/ModuleWithInstanceVariables

  def total_time_spent
    timelogs.sum(:time_spent)
  end

  def human_total_time_spent
    Gitlab::TimeTrackingFormatter.output(total_time_spent)
  end

  def time_change
    @timelog&.time_spent.to_i # rubocop:disable Gitlab/ModuleWithInstanceVariables
  end

  def human_time_change
    Gitlab::TimeTrackingFormatter.output(time_change)
  end

  def human_time_estimate
    Gitlab::TimeTrackingFormatter.output(time_estimate)
  end

  def time_estimate=(val)
    val.is_a?(Integer) ? super([val, Gitlab::Database::MAX_INT_VALUE].min) : super(val)
  end

  def set_time_estimate_default_value
    return if new_record?
    return unless has_attribute?(:time_estimate)

    self.time_estimate ||= self.class.column_defaults['time_estimate']
  end

  private

  def reset_spent_time
    timelogs.new(time_spent: total_time_spent * -1, user: @time_spent_user) # rubocop:disable Gitlab/ModuleWithInstanceVariables
  end

  # rubocop:disable Gitlab/ModuleWithInstanceVariables
  def add_or_subtract_spent_time
    timelogs.new(
      time_spent: time_spent,
      note_id: @time_spent_note_id,
      user: @time_spent_user,
      spent_at: @spent_at,
      summary: @summary
    )
  end
  # rubocop:enable Gitlab/ModuleWithInstanceVariables

  def check_negative_time_spent
    return if time_spent.nil? || time_spent == :reset

    if time_spent < 0 && (time_spent.abs > original_total_time_spent)
      errors.add(:base, _('Time to subtract exceeds the total time spent'))
    end
  end

  # we need to cache the total time spent so multiple calls to #valid?
  # doesn't give a false error
  def original_total_time_spent
    @original_total_time_spent ||= total_time_spent
  end

  def check_time_estimate
    return unless new_record? || time_estimate_changed?
    return if time_estimate.is_a?(Numeric) && time_estimate >= 0

    errors.add(:time_estimate, _('must have a valid format and be greater than or equal to zero.'))
  end
end
