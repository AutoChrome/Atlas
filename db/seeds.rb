admin = User.find_or_create_by!(email_address: "admin@example.com") do |user|
  user.name = "Admin"
  user.role = :admin
  user.password = "password123"
  user.password_confirmation = "password123"
end

getting_started = Area.find_or_create_by!(slug: "getting-started") do |area|
  area.name = "Getting Started"
  area.description = "Onboarding guides and the basics."
  area.public = true
  area.position = 0
end

welcome = getting_started.pages.find_or_initialize_by(slug: "welcome")
if welcome.new_record?
  welcome.title = "Welcome"
  welcome.public = true
  welcome.user = admin
  welcome.content = "<p>Welcome to Atlas — FirstB2B's documentation platform. This page is public — " \
                     "anyone with the link can read it without signing in.</p>" \
                     "<p>Sign in as <strong>admin@example.com</strong> / <strong>password123</strong> to " \
                     "create areas and pages, invite teammates, and manage API tokens.</p>"
  welcome.save!
end

puts "Seeded: #{User.count} user(s), #{Area.count} area(s), #{Page.count} page(s)."
