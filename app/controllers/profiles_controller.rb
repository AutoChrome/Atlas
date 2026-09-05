class ProfilesController < ApplicationController
  def edit
    @user = real_current_user
  end

  def update
    @user = real_current_user

    if @user.update(profile_params)
      redirect_to edit_profile_path, notice: "Profile updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def profile_params
      permitted = params.require(:user).permit(:name, :password, :password_confirmation)
      permitted[:password].blank? ? permitted.except(:password, :password_confirmation) : permitted
    end
end
