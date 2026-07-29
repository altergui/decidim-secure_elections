# frozen_string_literal: true

# The census lives in Decidim.
#
# Before this table the admin had to paste a Vocdoni "member group id" that
# could only be obtained by calling the SaaS API by hand. Decidim now collects
# the voters itself and the publish job creates the members, the group and the
# census upstream — no identifier is ever shown to, or asked of, an admin.
#
# Columns mirror the Vocdoni memberbase one-for-one (ARCHITECTURE §4c), in Rails
# naming: `memberNumber` → `member_number`, `nationalId` → `national_id`,
# `birthDate` → `birth_date`.
class CreateDecidimVocdoniCensusMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :decidim_vocdoni_census_members do |t|
      t.references :decidim_vocdoni_election,
                   null: false,
                   foreign_key: { to_table: :decidim_vocdoni_elections },
                   index: { name: "index_vocdoni_census_members_on_election_id" }

      t.string :name
      t.string :surname
      t.string :email
      t.string :phone
      t.string :member_number
      t.string :national_id
      t.date :birth_date

      # Voting power. Only sent upstream when the election is `weighted`;
      # otherwise every member counts as one, whatever is stored here.
      t.integer :weight, null: false, default: 1

      # Set by the publish job once the member exists in the Vocdoni
      # memberbase. It is what lets the `missingData` array returned by the
      # group validation (HTTP 400, code 40037) be mapped back onto rows, so
      # the admin is told *which people* are missing an email rather than that
      # "validation failed".
      t.string :vocdoni_member_id, index: { name: "index_vocdoni_census_members_on_member_id" }

      t.timestamps
    end

    # Lookup indexes for the duplicate checks the forms and the CSV importer
    # run. Not unique at the database level: uniqueness is scoped to an
    # election *and* only meaningful for the fields that election authenticates
    # on, which is a decision the model makes, not the schema.
    add_index :decidim_vocdoni_census_members,
              [:decidim_vocdoni_election_id, :email],
              name: "index_vocdoni_census_members_on_election_and_email"
    add_index :decidim_vocdoni_census_members,
              [:decidim_vocdoni_election_id, :member_number],
              name: "index_vocdoni_census_members_on_election_and_number"
  end
end
