require "io/console"

namespace :users do
  desc "Create a user. Prompts interactively, or pass NAME=, EMAIL=, ROLE=(member|admin|guest), PASSWORD= for non-interactive use."
  task create: :environment do
    name     = ENV["NAME"].presence     || prompt("Name")
    email    = ENV["EMAIL"].presence    || prompt("Email address")
    role     = ENV["ROLE"].presence     || prompt("Role (member/admin/guest) [member]").presence || "member"
    password = ENV["PASSWORD"].presence || prompt_password

    unless User.roles.key?(role)
      abort "Unknown role \"#{role}\" — must be one of: #{User.roles.keys.join(', ')}"
    end

    user = User.new(
      name: name,
      email_address: email,
      role: role,
      password: password,
      password_confirmation: password
    )

    if user.save
      puts "Created #{user.role} user #{user.email_address} (#{user.name})."
    else
      abort "Could not create user:\n#{user.errors.full_messages.map { |m| "  - #{m}" }.join("\n")}"
    end
  end
end

def prompt(label)
  print "#{label}: "
  $stdin.gets&.chomp.to_s
end

def prompt_password
  print "Password (min 8 characters, input hidden): "
  password = $stdin.noecho(&:gets)&.chomp.to_s
  puts

  print "Confirm password: "
  confirmation = $stdin.noecho(&:gets)&.chomp.to_s
  puts

  abort "Passwords didn't match." unless password == confirmation
  password
end
