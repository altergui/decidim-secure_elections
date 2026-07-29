# frozen_string_literal: true

# The factories a module's own specs use are the same ones a downstream module
# needs, so they live in `lib/` and ship with the gem — the Decidim convention,
# and what makes `require "decidim/secure_elections/test/factories"` work from anywhere.
require "decidim/secure_elections/test/factories"
