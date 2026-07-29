# frozen_string_literal: true

# Weighted voting — "Voting power" in the Vocdoni app.
#
# When false the `weight` of every census member is ignored and each person
# counts once; it is sent upstream as `census.weighted` in the process payload
# (ARCHITECTURE §2.1) and to the census publish call.
#
# The other census columns — `census_auth_fields`, `census_two_fa_fields`,
# `census_group_id`, `census_size` — already exist. `census_group_id` stays a
# cache written by the publish job and is never shown in, or read from, the
# admin UI.
class AddCensusSettingsToDecidimVocdoniElections < ActiveRecord::Migration[8.0]
  def change
    add_column :decidim_vocdoni_elections, :weighted, :boolean, null: false, default: false
  end
end
