require 'rails_helper'

RSpec.describe "Evaluations", type: :request do
  let(:user) { create(:user) }
  let(:goal) { create(:goal, user: user) }
  let(:focus_option) do
    FocusOption.create!(
      result_code: "focused",
      label: "集中できた",
      point: 2,
      position: 1
    )
  end
  let(:challenge_option) do
    ChallengeOption.create!(
      result_code: "challenged",
      label: "挑戦できた",
      point: 3,
      position: 1
    )
  end
  let(:study_record) do
    StudyRecord.create!(
      user: user,
      goal: goal,
      planned_minutes: 25,
        activity: "RSpecの学習",
        started_at: Time.current,
        status: study_record_status,
        rank: study_record_status == :evaluated ? :a : nil
      )
  end
  let(:evaluation_params) do
    {
      evaluation: {
        focus_option_id: focus_option.id,
        challenge_option_id: challenge_option.id
      }
    }
  end

  before do
    sign_in(user)
  end

  describe "GET /study_records/:study_record_id/evaluation/new" do
    context "学習記録が評価待ちの場合" do
      let(:study_record_status) { :awaiting_evaluation }

      it "評価入力画面を表示する" do
        get new_study_record_evaluation_path(study_record)

        expect(response).to have_http_status(:ok)
      end
    end

    context "学習記録が評価済みの場合" do
      let(:study_record_status) { :evaluated }

      it "評価結果画面へ遷移する" do
        get new_study_record_evaluation_path(study_record)

        expect(response).to redirect_to(study_record_evaluation_path(study_record))
        expect(response).to have_http_status(:see_other)
      end
    end

    [ :running, :paused ].each do |status|
      context "学習記録が#{status}の場合" do
        let(:study_record_status) { status }

        it "学習記録のshow画面へ遷移する" do
          get new_study_record_evaluation_path(study_record)

          expect(response).to redirect_to(study_record_path(study_record))
          expect(response).to have_http_status(:see_other)
        end
      end
    end
  end

  describe "GET /study_records/:study_record_id/evaluation" do
    subject(:perform_request) do
      get study_record_evaluation_path(study_record)
    end

    context "学習記録が評価済みの場合" do
      let(:study_record_status) { :evaluated }

      before do
        Evaluation.create!(
          study_record: study_record,
          focus_option: focus_option,
          challenge_option: challenge_option
        )
      end

      it "評価結果画面を表示する" do
        perform_request

        expect(response).to have_http_status(:ok)
      end
    end

    context "学習記録が評価待ちの場合" do
      let(:study_record_status) { :awaiting_evaluation }

      it "評価入力画面へ遷移する" do
        perform_request

        expect(response).to redirect_to(
          new_study_record_evaluation_path(study_record)
        )
        expect(response).to have_http_status(:see_other)
      end
    end

    [ :running, :paused ].each do |status|
      context "学習記録が#{status}の場合" do
        let(:study_record_status) { status }

        it "学習記録画面へ遷移する" do
          perform_request

          expect(response).to redirect_to(study_record_path(study_record))
          expect(response).to have_http_status(:see_other)
        end
      end
    end
  end

  describe "POST /study_records/:study_record_id/evaluation" do
    context "学習記録が評価待ちの場合" do
      let(:study_record_status) { :awaiting_evaluation }

      it "評価を保存して評価済みに変更する" do
        expect {
          post study_record_evaluation_path(study_record), params: evaluation_params
        }.to change(Evaluation, :count).by(1)

        expect(study_record.reload).to be_evaluated
        expect(response).to redirect_to(study_record_evaluation_path(study_record))
        expect(response).to have_http_status(:see_other)
      end

      it "評価の保存に失敗した場合は評価待ちのままにする" do
        expect {
          post study_record_evaluation_path(study_record), params: {
            evaluation: { focus_option_id: focus_option.id }
          }
        }.not_to change(Evaluation, :count)

        expect(study_record.reload).to be_awaiting_evaluation
        expect(response).to have_http_status(:unprocessable_content)
      end

      context "気づきを一緒に送る場合" do
        def post_with_insight(insight)
          post study_record_evaluation_path(study_record),
               params: evaluation_params.merge(insight: insight)
        end

        it "両方を書いた場合は、評価と気づき2件を保存する" do
          expect {
            post_with_insight(went_well: "最初の5分は音読から始めた", to_improve: "スマホを別の部屋に置く")
          }.to change(Evaluation, :count).by(1).and change(Insight, :count).by(2)

          expect(study_record.reload).to be_evaluated
          expect(response).to redirect_to(study_record_evaluation_path(study_record))
          expect(response).to have_http_status(:see_other)
        end

        it "片方だけ書いた場合は、書いた方だけを保存する" do
          expect {
            post_with_insight(went_well: "最初の5分は音読から始めた", to_improve: "")
          }.to change(Evaluation, :count).by(1).and change(Insight, :count).by(1)

          expect(study_record.insights.pluck(:kind)).to eq(["went_well"])
        end

        it "両方とも空欄の場合は、評価だけを保存する" do
          expect {
            post_with_insight(went_well: "", to_improve: "")
          }.to change(Evaluation, :count).by(1).and change(Insight, :count).by(0)

          expect(study_record.reload).to be_evaluated
        end

        it "空白だけの場合は、評価だけを保存する" do
          expect {
            post_with_insight(went_well: "   ", to_improve: "　　")
          }.to change(Evaluation, :count).by(1).and change(Insight, :count).by(0)
        end

        it "前後の空白（全角を含む）を消して保存する" do
          post_with_insight(went_well: "　集中できた　", to_improve: "")

          expect(study_record.insights.pluck(:body)).to eq(["集中できた"])
        end

        it "気づきが100字を超える場合は、正しく書いた方も含めて何も保存せず評価待ちのままにする" do
          expect {
            post_with_insight(went_well: "最初の5分は音読から始めた", to_improve: "あ" * 101)
          }.to change(Evaluation, :count).by(0).and change(Insight, :count).by(0)

          expect(study_record.reload).to be_awaiting_evaluation
          expect(study_record.rank).to be_nil
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include(%(action="#{study_record_evaluation_path(study_record)}"))
        end
      end
    end

    context "学習記録が評価済みの場合" do
      let(:study_record_status) { :evaluated }

      it "評価を保存せず評価結果画面へ遷移する" do
        expect {
          post study_record_evaluation_path(study_record), params: evaluation_params
        }.not_to change(Evaluation, :count)

        expect(response).to redirect_to(study_record_evaluation_path(study_record))
        expect(response).to have_http_status(:see_other)
      end
    end

    [ :running, :paused ].each do |status|
      context "学習記録が#{status}の場合" do
        let(:study_record_status) { status }

        it "評価を保存せず学習記録のshow画面へ遷移する" do
          expect {
            post study_record_evaluation_path(study_record), params: evaluation_params
          }.not_to change(Evaluation, :count)

          expect(response).to redirect_to(study_record_path(study_record))
          expect(response).to have_http_status(:see_other)
        end
      end
    end
  end
end
