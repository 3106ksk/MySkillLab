class EvaluationSubmission
  def self.call(evaluation:, study_record:)
    new(evaluation: evaluation, study_record: study_record).call
  end

  def initialize(evaluation:, study_record:)
    @evaluation = evaluation
    @study_record = study_record
  end

  def call
    StudyRecord.transaction do
      if evaluation.save
        rank_code = RankDeterminer.call(
          focus_point: evaluation.focus_point,
          challenge_point: evaluation.challenge_point
        )

        study_record.mark_as_evaluated!(rank_code)
      else
        false
      end
    end
  end

  private

  attr_reader :evaluation, :study_record
end
