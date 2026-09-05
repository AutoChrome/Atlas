module ApplicationHelper
  include Pagy::Frontend

  # An area plus all of its ancestors, root first — the chain a breadcrumb
  # trail walks down to reach it.
  def area_ancestors(area)
    chain = []
    current = area

    while current
      chain.unshift(current)
      current = current.parent
    end

    chain
  end

  # Development gets an inverted-colour variant of the production favicon
  # (public/icon-dev.svg vs public/icon.svg) — same glyph, swapped
  # foreground/background, so a dev tab is visually distinct from
  # production at a glance in a crowded tab strip.
  def favicon_path
    Rails.env.development? ? "/icon-dev.svg" : "/icon.svg"
  end
end
