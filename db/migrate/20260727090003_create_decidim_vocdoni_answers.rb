# frozen_string_literal: true

class CreateDecidimVocdoniAnswers < ActiveRecord::Migration[8.0]
  def change
    create_table :decidim_vocdoni_answers do |t|
      t.references :decidim_vocdoni_question,
                   null: false,
                   foreign_key: { to_table: :decidim_vocdoni_questions },
                   index: { name: "index_vocdoni_answers_on_question_id" }

      t.jsonb :title, null: false, default: {}

      # 0-based choice value as encoded on chain. Unique within a question.
      t.integer :value, null: false
      t.integer :position

      t.integer :votes_count, null: false, default: 0

      t.timestamps
    end

    add_index :decidim_vocdoni_answers,
              [:decidim_vocdoni_question_id, :value],
              unique: true,
              name: "index_vocdoni_answers_on_question_id_and_value"
  end
end
