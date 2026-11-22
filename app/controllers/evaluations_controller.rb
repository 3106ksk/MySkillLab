class EvaluationsController < ApplicationController
  layout "focus"

  before_action :set_study_record
  before_action :ensure_awaiting_evaluation, only: %i[new create]
  before_action :ensure_evaluated, only: :show

  def new
    @evaluation = Evaluation.new
    @evaluation.study_record = @study_record
    set_evaluation_options
  end

  def create
    @evaluation = @study_record.build_evaluation(evaluation_params)

    if EvaluationSubmission.call(
      evaluation: @evaluation,
      study_record: @study_record,
      insight_params: insight_params
    )
      redirect_to study_record_evaluation_path(@study_record), status: :see_other
    else
      render_evaluation_form
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to study_record_evaluation_path(@study_record), status: :see_other
  rescue RankDeterminer::InvalidTotalPointError
    @evaluation.errors.add(
      :base,
      "評価結果を保存できませんでした。もう一度お試しください"
    )

    render_evaluation_form
  rescue ActiveRecord::RecordInvalid => e
    if e.record.class == Insight
      @failed_insight = e.record
    else
      @evaluation.errors.add(
        :base,
        "評価結果を保存できませんでした。もう一度お試しください"
      )
    end

    render_evaluation_form
  end

  def show
    @evaluation = @study_record.evaluation
  end

  private

  def set_study_record
    @study_record = current_user.study_records.find(params[:study_record_id])
  end

  def ensure_awaiting_evaluation
    return if @study_record.awaiting_evaluation?

    destination =
      if @study_record.evaluated?
        study_record_evaluation_path(@study_record)
      else
        @study_record
      end

    redirect_to destination, status: :see_other
  end

  def ensure_evaluated
    return if @study_record.evaluated?

    destination =
      if @study_record.awaiting_evaluation?
        new_study_record_evaluation_path(@study_record)
      else
        @study_record
      end

    redirect_to destination, status: :see_other
  end

  def evaluation_params
    params.fetch(:evaluation, {}).permit(:focus_option_id, :challenge_option_id)
  end

  def insight_params
    params.fetch(:insight, {}).permit(:went_well, :to_improve)
  end

  def set_evaluation_options
    @focus_options = FocusOption.display_order
    @challenge_options = ChallengeOption.display_order
  end

  def render_evaluation_form
    set_evaluation_options
    render :new, status: :unprocessable_entity
  end
end
