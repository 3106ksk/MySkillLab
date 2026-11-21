class EvaluationSubmission
  def self.call(evaluation:, study_record:, insight_params:)
    new(evaluation: evaluation, study_record: study_record, insight_params: insight_params).call
  end

  def initialize(evaluation:, study_record:, insight_params:)
    @evaluation = evaluation
    @study_record = study_record
    @insight_params = insight_params
  end

  def call
    StudyRecord.transaction do
      if evaluation.save
        rank_code = RankDeterminer.call(
          focus_point: evaluation.focus_point,
          challenge_point: evaluation.challenge_point
        )

        study_record.mark_as_evaluated!(rank_code)

        insight_params.each do |kind, body|
          next if body.blank?

          insight = study_record.insights.build(kind: kind, body: body)
          insight.save!
        end

        true
      else
        false
      end
    end
  end

  private

  attr_reader :evaluation, :study_record, :insight_params
end
