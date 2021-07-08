# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Menu
          extend QA::Page::PageConcern

          def self.prepended(base)
            super

            base.class_eval do
              prepend QA::Page::Group::SubMenus::Common

              view 'app/views/layouts/nav/sidebar/_group_menus.html.haml' do
                element :group_sidebar_submenu
                element :group_settings
              end

              view 'ee/app/views/groups/ee/_administration_nav.html.haml' do
                element :group_administration_link
                element :group_sidebar_submenu_content
                element :group_saml_sso_link
              end

              view 'ee/app/views/groups/ee/_settings_nav.html.haml' do
                element :ldap_synchronization_link
                element :billing_link
              end
            end
          end

          def go_to_issue_boards
            hover_issues do
              within_submenu do
                click_element(:sidebar_menu_item_link, menu_item: 'Boards')
              end
            end
          end

          def go_to_group_iterations
            hover_issues do
              within_submenu do
                click_element(:sidebar_menu_item_link, menu_item: 'Iterations')
              end
            end
          end

          def go_to_saml_sso_group_settings
            hover_element(:group_administration_link) do
              within_submenu(:group_sidebar_submenu_content) do
                click_element(:group_saml_sso_link)
              end
            end
          end

          def go_to_ldap_sync_settings
            hover_element(:group_settings) do
              within_submenu(:group_sidebar_submenu) do
                click_element(:ldap_synchronization_link)
              end
            end
          end

          def click_contribution_analytics_item
            hover_group_analytics do
              within_submenu do
                click_element(:sidebar_menu_item_link, menu_item: 'Contribution')
              end
            end
          end

          def click_group_insights_link
            hover_group_analytics do
              within_submenu do
                click_element(:sidebar_menu_item_link, menu_item: 'Insights')
              end
            end
          end

          def click_group_general_settings_item
            hover_element(:group_settings) do
              within_submenu(:group_sidebar_submenu) do
                click_element(:general_settings_link)
              end
            end
          end

          def click_group_epics_link
            within_sidebar do
              click_element(:sidebar_menu_link, menu_item: 'Epics')
            end
          end

          def click_group_security_link
            hover_security_and_compliance do
              within_submenu do
                click_element(:sidebar_menu_item_link, menu_item: 'Security Dashboard')
              end
            end
          end

          def click_group_vulnerability_link
            hover_security_and_compliance do
              within_submenu do
                click_element(:sidebar_menu_item_link, menu_item: 'Vulnerability Report')
              end
            end
          end

          def go_to_audit_events
            hover_security_and_compliance do
              within_submenu do
                click_element(:sidebar_menu_item_link, menu_item: 'Audit Events')
              end
            end
          end

          def click_group_wiki_link
            within_sidebar do
              scroll_to_element(:sidebar_menu_link, menu_item: 'Wiki')
              click_element(:sidebar_menu_link, menu_item: 'Wiki')
            end
          end

          def go_to_billing
            hover_element(:group_settings) do
              within_submenu(:group_sidebar_submenu) do
                click_element(:billing_link)
              end
            end
          end

          private

          def hover_security_and_compliance
            within_sidebar do
              scroll_to_element(:sidebar_menu_link, menu_item: 'Security & Compliance')
              find_element(:sidebar_menu_link, menu_item: 'Security & Compliance').hover

              yield
            end
          end

          def hover_group_analytics
            within_sidebar do
              scroll_to_element(:sidebar_menu_link, menu_item: 'Analytics')
              find_element(:sidebar_menu_link, menu_item: 'Analytics').hover

              yield
            end
          end
        end
      end
    end
  end
end
