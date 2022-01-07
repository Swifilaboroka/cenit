class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.

  protect_from_forgery with: :null_session, if: -> { request.format.json? }

  rescue_from CanCan::AccessDenied, RailsAdmin::ActionNotAllowed do |exception|
    if _current_user
      redirect_to main_app.root_path, alert: exception.message
    else
      redirect_to new_session_path(User)
    end
  end

  around_filter :scope_current_account

  before_action :redirect_if_not_logged

  def redirect_if_not_logged
    if current_user.nil? && params[:controller] == "rails_admin/main" && params[:action] == "dashboard"
      redirect_to "https://web.cenit.io"
    end
  end

  protected

  def do_optimize
    Setup::Optimizer.save_namespaces
  end

  private

  def optimize
    do_optimize
  end

  def clean_thread_cache
    Thread.clean_keys_prefixed_with('[cenit]')
  end

  def scope_current_account
    Account.current = nil
    clean_thread_cache
    if current_user && current_user.account.nil?
      current_user.account = current_user.accounts.first || Account.new_for_create(owner: current_user)
      current_user.save(validate: false)
    end
    Account.current = current_user.account.target if signed_in?
    yield
  ensure
    optimize
    if (account = Account.current)
      account.save(discard_events: true)
    end
    clean_thread_cache
  end

  def after_sign_in_path_for(resource_or_scope)
    if params[:return_to]
      store_location_for(resource_or_scope, params[:return_to])
    else
      stored_location_for(resource_or_scope) || signed_in_root_path(resource_or_scope)
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    params[:return_to] || ENV['SING_OUT_URL'] || root_path
  end
end
