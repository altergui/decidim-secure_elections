# frozen_string_literal: true

# The editor's "Attach video" field, matching the live-stream URL the Vocdoni
# app offers.
#
# It is rendered on the public election page and is **not** sent upstream. The
# SaaS API's `streamUri` has not been verified against a real process, and a
# field whose value is passed to an endpoint that may reject the whole payload
# would turn "an admin pasted a video link" into "publishing this election
# fails". Wiring it through is a separate change, gated on that verification.
class AddStreamUriToDecidimVocdoniElections < ActiveRecord::Migration[8.0]
  def change
    add_column :decidim_vocdoni_elections, :stream_uri, :string
  end
end
