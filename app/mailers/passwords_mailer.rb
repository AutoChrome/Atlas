class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "Reset your password", to: user.email_address
  end

  # Sent when an admin creates an account (Admin::UsersController#create) or
  # asks to resend the invite (#resend_setup_email). Reuses the same
  # password-reset token — there's nothing meaningfully different about
  # "set your first password" vs. "reset your password" mechanically.
  def account_setup(user)
    @user = user
    mail subject: "Set up your Atlas account", to: user.email_address
  end
end
