module Admin
  class UsersController < BaseController
    before_action :set_user, only: %i[edit update destroy resend_setup_email]

    def index
      authorize User
      @users = policy_scope(User).order(:name)
    end

    def new
      @user = User.new
      authorize @user
    end

    # No password field on this form — admins never handle user passwords.
    # A random, never-displayed password satisfies has_secure_password's
    # presence check; the user sets a real one via the emailed link.
    def create
      @user = User.new(user_params)
      @user.password = @user.password_confirmation = SecureRandom.hex(20)
      authorize @user

      if @user.save
        PasswordsMailer.account_setup(@user).deliver_later
        redirect_to admin_users_path, notice: "User created. An email has been sent to #{@user.email_address} to set up their password."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @user
    end

    def update
      authorize @user

      if @user.update(user_params)
        redirect_to admin_users_path, notice: "User updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @user
      @user.destroy
      redirect_to admin_users_path, notice: "User removed.", status: :see_other
    end

    def resend_setup_email
      authorize @user, :update?
      PasswordsMailer.account_setup(@user).deliver_later
      redirect_to admin_users_path, notice: "Setup email resent to #{@user.email_address}."
    end

    private
      def set_user
        @user = User.find(params[:id])
      end

      def user_params
        params.require(:user).permit(:name, :email_address, :role)
      end
  end
end
