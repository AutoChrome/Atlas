# dartsass-rails's own `dartsass:watch` task relies on filesystem change
# events, which don't reliably cross the bind mount Docker Desktop uses on
# Windows — SCSS edits silently didn't recompile without this. `--poll`
# fixes it, but dart-sass rejects that flag on a plain (non-watch) compile,
# so it can't just go in config.dartsass.build_options (shared with
# `dartsass:build`, which also backs assets:precompile and test:prepare) —
# it needs its own task. Used by Procfile.dev instead of dartsass:watch.
namespace :dartsass do
  desc "Watch and build Dart Sass CSS on file changes, polling instead of relying on FS events"
  task watch_poll: :environment do
    require "dartsass/runner"
    system(*Dartsass::Runner.dartsass_compile_command, "--watch", "--poll", exception: true)
  end
end
