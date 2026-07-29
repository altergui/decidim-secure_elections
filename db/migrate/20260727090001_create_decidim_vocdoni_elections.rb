# frozen_string_literal: true

class CreateDecidimVocdoniElections < ActiveRecord::Migration[8.0]
  def change
    create_table :decidim_vocdoni_elections do |t|
      # `bigint` and a real foreign key, to match `decidim_components.id`.
      # Without the key, deleting a component orphans its elections — and with
      # them their census members, whose `dependent: :destroy` would never fire.
      # Those rows are personal data, so leaving them behind is not only untidy.
      t.references :decidim_component,
                   null: false,
                   foreign_key: { to_table: :decidim_components },
                   index: { name: "index_vocdoni_elections_on_component_id" }

      t.jsonb :title, null: false, default: {}
      t.jsonb :description, default: {}

      # `start_time` is nullable on purpose: a process without a start date
      # starts the moment it is published on chain.
      t.datetime :start_time, index: { name: "index_vocdoni_elections_on_start_time" }
      t.datetime :end_time, index: { name: "index_vocdoni_elections_on_end_time" }

      t.datetime :published_at, index: { name: "index_vocdoni_elections_on_published_at" }
      t.datetime :deleted_at, index: { name: "index_vocdoni_elections_on_deleted_at" }

      # Vocdoni process (Mongo ObjectID, 24 hex chars). Null until the election
      # has been pushed on chain; its presence is what makes the election
      # immutable.
      t.string :vocdoni_process_id, index: { name: "index_vocdoni_elections_on_process_id" }
      t.string :vocdoni_chain_id

      # Inline census definition sent with `POST /processes`. An election with
      # no auth fields enfranchises nobody and must never be published.
      t.jsonb :census_auth_fields, null: false, default: []
      t.jsonb :census_two_fa_fields, null: false, default: []
      t.string :census_group_id
      t.integer :census_size, null: false, default: 0

      t.string :status, null: false, default: "draft", index: { name: "index_vocdoni_elections_on_status" }

      # Last tally read from the API. Every UI read goes through this column so
      # that polling never fans out into upstream calls.
      t.jsonb :results_cache, null: false, default: {}
      t.datetime :results_synced_at
      t.integer :votes_count, null: false, default: 0

      t.string :reference

      t.timestamps
    end
  end
end
