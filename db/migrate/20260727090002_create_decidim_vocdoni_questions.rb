# frozen_string_literal: true

class CreateDecidimVocdoniQuestions < ActiveRecord::Migration[8.0]
  def change
    create_table :decidim_vocdoni_questions do |t|
      t.references :decidim_vocdoni_election,
                   null: false,
                   foreign_key: { to_table: :decidim_vocdoni_elections },
                   index: { name: "index_vocdoni_questions_on_election_id" }

      t.jsonb :title, null: false, default: {}
      t.jsonb :description, default: {}

      t.string :question_type, null: false, default: "singlechoice"
      t.integer :max_choices
      t.integer :min_choices
      t.boolean :secret_until_the_end, null: false, default: false
      t.integer :position

      # Identifier of the question inside the Vocdoni process.
      t.string :vocdoni_question_id
      # The question's own Vochain election id. This — never the process id — is
      # what the browser signs and votes against.
      t.string :vocdoni_upstream_id, index: { name: "index_vocdoni_questions_on_upstream_id" }
      t.string :vocdoni_status

      t.integer :answers_count, null: false, default: 0

      t.timestamps
    end
  end
end
