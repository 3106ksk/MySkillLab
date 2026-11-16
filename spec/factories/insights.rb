FactoryBot.define do
  factory :insight do
    study_record
    kind { "went_well" }
    body { "最初の5分は音読から始めた" }
  end
end
