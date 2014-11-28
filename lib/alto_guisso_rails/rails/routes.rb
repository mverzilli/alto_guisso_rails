module ActionDispatch::Routing
  class Mapper
    def guisso_for(mapping)
      if Guisso.enabled? && defined?(Devise)
        mapping = Devise.mappings[mapping].name

        ActionController::Base.class_eval <<-METHODS, __FILE__, __LINE__ + 1
          unless method_defined?(:check_guisso_cookie)
            before_filter :check_guisso_cookie
          end

          def check_guisso_cookie
            guisso_email = cookies[:guisso]
            if guisso_email.present?
              if guisso_email == "logout"
                sign_out current_#{mapping} if current_#{mapping}
              elsif !current_#{mapping} || guisso_email != current_#{mapping}.email
                redirect_to_guisso
              end
            end
          end

          def authenticate_#{mapping}_with_guisso!(*args)
            if current_#{mapping}
              guisso_email = cookies[:guisso]
              if guisso_email
                if guisso_email == current_#{mapping}.email
                  return authenticate_#{mapping}_without_guisso!(*args)
                else
                  sign_out current_#{mapping}
                  return redirect_to_guisso
                end
              end
              sign_in current_#{mapping}
            elsif params[:format] && params[:format] != :html
              head :unauthorized
            else
              redirect_to_guisso
            end
          end

          def current_#{mapping}_with_guisso
            unless @currrent_#{mapping}
              if request.authorization && request.authorization =~ /^Basic (.*)/m
                email, password = Base64.decode64($1).split(/:/, 2)
                if AltoGuissoRails.valid_credentials?(email, password)
                  @current_#{mapping} = #{mapping.to_s.capitalize}.find_by_email email
                end
              end
            end

            @current_#{mapping} ||= current_#{mapping}_without_guisso
          end

          unless method_defined?(:authenticate_#{mapping}_without_guisso!)
            alias_method_chain :authenticate_#{mapping}!, :guisso
          end

          unless method_defined?(:current_#{mapping}_without_guisso)
            alias_method_chain :current_#{mapping}, :guisso
          end

          def redirect_to_guisso(*args)
            redirect_to #{mapping}_omniauth_authorize_path(:instedd, *args)
          end

          def authenticate_api_#{mapping}!
            return if @current_#{mapping}

            if (req = env["guisso.oauth2.req"])
              email = AltoGuissoRails.validate_oauth2_request(req)
              if email
                @current_#{mapping} = find_or_create_user(email)
                return
              end
            elsif request.authorization && request.authorization =~ /^Basic (.*)/m
              email, password = Base64.decode64($1).split(/:/, 2)
              if AltoGuissoRails.valid_credentials?(email, password)
                @current_#{mapping} = find_or_create_user(email)
                return
              end
            end

            # try to authenticate using other methods defined in current_#{mapping}
            return if current_#{mapping}

            head :unauthorized
          end

          def find_or_create_user(email)
            user = #{mapping.to_s.capitalize}.find_or_create_by_email(email)
            if user.new_record?
              user.confirmed_at = Time.now
              user.password = Devise.friendly_token
              user.save!
            end
            user
          end
        METHODS
      else
        ActionController::Base.class_eval <<-METHODS, __FILE__, __LINE__ + 1
          def authenticate_#{mapping}_without_guisso!
            authenticate_#{mapping}!
          end

          def authenticate_api_#{mapping}!
            authenticate_#{mapping}!
          end
        METHODS
      end
    end
  end
end
