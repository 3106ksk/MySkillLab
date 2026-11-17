require 'rails_helper'

RSpec.describe Insight, type: :model do
  describe "バリデーション" do
    it "よかったことは保存できる" do
      expect(build(:insight, kind: "went_well")).to be_valid
    end

    it "次への改善点は保存できる" do
      expect(build(:insight, kind: "to_improve")).to be_valid
    end

    it "本文が空白だけだと保存できない" do
      insight = build(:insight, body: "   ")

      expect(insight).to be_invalid
      expect(insight.errors[:body]).to be_present
    end

    it "本文が空だと保存できない" do
      insight = build(:insight, body: "")

      expect(insight).to be_invalid
      expect(insight.errors[:body]).to be_present
    end

    it "本文が100文字なら保存できる" do
      expect(build(:insight, body: "あ" * 100)).to be_valid
    end

    it "本文が101文字だと保存できない" do
      insight = build(:insight, body: "あ" * 101)

      expect(insight).to be_invalid
      expect(insight.errors[:body]).to be_present
    end

    it "種類が2つの値以外だと保存できない" do
      insight = build(:insight, kind: "other")

      expect(insight).to be_invalid
      expect(insight.errors[:kind]).to be_present
    end

    context "同じ学習に、同じ種類の気づきが既にある場合" do
      it "2件目は無効になり、種類にエラーが入る" do
        insight = create(:insight, kind: "went_well")
        duplicate = build(:insight, study_record: insight.study_record, kind: "went_well")

        expect(duplicate).to be_invalid
        expect(duplicate.errors[:kind]).to be_present
      end
    end

    context "同じ学習に、違う種類の気づきがある場合" do
      it "2件目も保存できる" do
        insight = create(:insight, kind: "went_well")
        other = build(:insight, study_record: insight.study_record, kind: "to_improve")

        expect(other).to be_valid
      end
    end
  end

  describe "関連データの削除" do
    context "学習記録を削除した場合" do
      it "紐づく気づきも削除される" do
        insight = create(:insight)

        expect { insight.study_record.destroy! }
          .to change(described_class, :count).by(-1)
      end
    end
  end
end
