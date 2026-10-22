# frozen_string_literal: true

# The commit this build came from, so "which revision is actually running?" is
# answerable without guessing.
#
# The Dockerfile writes VERSION at build time from a --build-arg GIT_SHA, so
# anything running from an image answers from the file without shelling out.
# Off the image there is no such file and we ask git instead, gated on .git
# rather than on the environment. A container has no .git (.dockerignore drops
# it), so it never shells out.
#
# This is deliberately a different thing from Wren::VERSION (config/version.rb).
# Both are worth having:
#
#   version   which release is this? Survives a rebuild of the same code, and is
#             what the image tag is named after.
#   revision  which commit is this? Precise, automatic, meaningless to read, and
#             the only thing that answers "is what I just built actually running?"
Rails.application.config.x.revision = begin
  version_file = Rails.root.join("VERSION")
  from_file = version_file.exist? ? version_file.read.strip.presence : nil

  from_git =
    if from_file.nil? && Rails.root.join(".git").exist?
      # Fails quietly on a checkout git will not touch (dubious ownership, no
      # git installed); the fallbacks below cover it.
      `git rev-parse --short HEAD 2>/dev/null`.strip.presence
    end

  from_file || from_git || ENV["GIT_SHA"].presence || "unknown"
end
