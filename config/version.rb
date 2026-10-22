# frozen_string_literal: true

# Wren's release version, SemVer, bumped by hand.
#
# **Bumping this file is what cuts a release.** .github/workflows/build.yml
# triggers on a change to this path on main: it builds the multi-arch image,
# publishes it to ghcr.io/dkam/wren, and creates the matching vX.Y.Z tag and
# GitHub Release. A pre-release (e.g. "0.2.0-dev") publishes :v0.2.0-dev but
# does not move :latest and is not tagged.
#
# Lives in config/ rather than lib/ so it can be read without booting Rails:
#   ruby -e "require './config/version'; puts Wren::VERSION"
module Wren
  VERSION = "0.1.0"
end
