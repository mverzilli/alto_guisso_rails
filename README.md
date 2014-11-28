# AltoGuissoRails

Alto Guisso Rails allows connecting your application with Guisso (Instedd's Single Sign On).

It provides two funcionalities:

1. Allow users to sign in with Guisso as an OpenId server.
2. Allow OAuth and Basic authentication with Guisso credentials.

## Installation

Add this line to your application's Gemfile:

    gem 'alto_guisso', github: "instedd/alto_guisso", branch: 'master'
    gem 'alto_guisso_rails', github: "instedd/alto_guisso_rails", branch: 'master'

And this ones if you are missing any of them:

* devise
* ruby-openid
* rack-oauth2
* omniauth
* omniauth-openid

And then execute:

    $ bundle

## Usage

### Allow users to sign in with Guisso as an OpenId server

* Require `openid` and some other files:

        # config/application.rb
        require "openid"
        require 'openid/extensions/sreg'
        require 'openid/extensions/pape'
        require 'openid/store/filesystem'

* Add `:omniauthable` to your devise Model

        # app/models/user.rb
        class User < ActiveRecord::Base
          devise :omniauthable, ...
        end

* Create a table and a model to store the OpenId identities:

        class CreateIdentities < ActiveRecord::Migration
          def change
            create_table :identities do |t|
              t.integer :user_id
              t.string :provider
              t.string :token

              t.timestamps
            end
          end
        end

        # app/models/identity.rb
        class Identity < ActiveRecord::Base
          belongs_to :user
        end

        # app/models/user.rb
        class User < ActiveRecord::Base
          has_many :identities, dependent: :destroy
        end

* Override Devise's omniauth callbacks controller:

        # config/routes.rb
        devise_for :users, controllers: {omniauth_callbacks: "omniauth_callbacks"}

        # app/controllers/omniauth_callbacks_controller.rb
        class OmniauthCallbacksController < Devise::OmniauthCallbacksController
          skip_before_action :verify_authenticity_token
          skip_before_filter :check_guisso_cookie

          def instedd
            generic do |auth|
              {
                email: auth.info['email'],
                # name: auth.info['name'],
              }
            end
          end

          def generic
            auth = env['omniauth.auth']

            if identity = Identity.find_by_provider_and_token(auth['provider'], auth['uid'])
              user = identity.user
            else
              attributes = yield auth

              user = User.find_by_email(attributes[:email])
              unless user
                password = Devise.friendly_token
                user = User.new(attributes.merge(password: password, password_confirmation: password))
                user.confirmed_at = Time.now
                user.save!
              end
              user.identities.create! provider: auth['provider'], token: auth['uid']
            end

            sign_in user
            next_url = env['omniauth.origin'] || root_path
            next_url = root_path if next_url == new_user_session_url
            redirect_to next_url
          end
        end

* Define Guisso in your routes for your Devise model:

        # config/routes.rb
        devise_for :users, ...
        # note that here it uses the singular form
        guisso_for :user

* Change the sign in paths to use Guisso:

        # Before:
        link_to "Sign in", new_user_session_path

        # After:
        link_to "Sign in", guisso_sign_in_path_for(:user)

* Change the settings paths to use Guisso:

        # Before:
        link_to 'Settings', edit_user_registration_path

        # After:
        link_to 'Settings', guisso_settings_path(:user)

* Change the sign up paths to use Guisso:

        # Before:
        link_to "Create account", new_user_registration_path

        # After:
        link_to "Create account", guisso_sign_up_path_for(:user)

* Add the Guisso configuration file:

        # config/guisso.yml
        enabled: true
        url: http://my-guisso.instedd.org:3001
        client_id:
        client_secret:


### Allow OAuth and Basic authentication with Guisso credentials.

In a controller that provides an API endpoint:

        class MyApiController < ApplicationController
          before_filter :authenticate_api_user!
        end

That is, you don't need to change anything.


## Running locally

Create local links for your projects:

        # /etc/hosts
        127.0.0.1 my-verboice.instedd.org (the project in which you want to include SSO)
        127.0.0.1 my-guisso.instedd.org

The domains need to be the same, and need to be "instedd.org".

Remember to update the url setting in your guisso.yml with this name and the port in which you are running your local version of Guisso.

## Migrating Users

Check out the instedd/guisso repository to find a rake task for migrating your application's existing users.

## Contributing

1. Fork it ( https://github.com/[my-github-username]/alto_guisso_rails/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
