defmodule SocialScribe.CRM.ProviderConfig do
  @moduledoc """
  Centralized CRM provider configuration. All CRM-specific data lives here.

  To add a new CRM provider:
  1. Add provider config to @providers below
  2. Implement CrmApiBehaviour callbacks in a new API module
  3. Implement a token refresher module
  4. Create Ueberauth OAuth strategy
  5. Add OAuth callback handler in AuthController
  6. Add route in router.ex
  7. Register API mock in test_helper.exs
  """

  @providers %{
    "hubspot" => %{
      name: "hubspot",
      display_name: "HubSpot",
      api_config_key: :hubspot_api,
      api_module: SocialScribe.HubspotApi,
      field_labels: %{
        "firstname" => "First Name",
        "lastname" => "Last Name",
        "email" => "Email",
        "phone" => "Phone",
        "mobilephone" => "Mobile Phone",
        "company" => "Company",
        "jobtitle" => "Job Title",
        "address" => "Address",
        "city" => "City",
        "state" => "State",
        "zip" => "ZIP Code",
        "country" => "Country",
        "website" => "Website",
        "linkedin_url" => "LinkedIn",
        "twitter_handle" => "Twitter"
      },
      ai_field_descriptions:
        "- Phone numbers (phone, mobilephone)\n- Email addresses (email)\n- Company name (company)\n- Job title/role (jobtitle)\n- Physical address details (address, city, state, zip, country)\n- Website URLs (website)\n- LinkedIn profile (linkedin_url)\n- Twitter handle (twitter_handle)",
      ai_field_names:
        "firstname, lastname, email, phone, mobilephone, company, jobtitle, address, city, state, zip, country, website, linkedin_url, twitter_handle",
      modal_submit_text: "Update HubSpot",
      modal_submit_class: "bg-hubspot-button hover:bg-hubspot-button-hover",
      button_class: "bg-orange-500 hover:bg-orange-600",
      overlay_class: "bg-hubspot-overlay/90",
      modal_description:
        "Here are suggested updates to sync with your integrations based on this meeting",
      uid_label: "UID",
      connect_button_class:
        "bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500",
      icon_svg_path:
        "M18.164 7.93V5.084a2.198 2.198 0 001.267-1.984v-.066A2.2 2.2 0 0017.231.834h-.066a2.2 2.2 0 00-2.2 2.2v.066c0 .873.517 1.626 1.267 1.984V7.93a6.152 6.152 0 00-3.267 1.643l-6.6-5.133a2.726 2.726 0 00.067-.582A2.726 2.726 0 003.706 1.13a2.726 2.726 0 00-2.726 2.727 2.726 2.726 0 002.726 2.727c.483 0 .938-.126 1.333-.347l6.486 5.047a6.195 6.195 0 00-.556 2.572 6.18 6.18 0 00.56 2.572l-1.57 1.223a2.457 2.457 0 00-1.49-.504 2.468 2.468 0 00-2.468 2.468 2.468 2.468 0 002.468 2.468 2.468 2.468 0 002.468-2.468c0-.29-.05-.568-.142-.826l1.558-1.213a6.2 6.2 0 003.812 1.312 6.2 6.2 0 006.199-6.2 6.2 6.2 0 00-4.2-5.856zm-4.2 9.193a3.337 3.337 0 110-6.674 3.337 3.337 0 010 6.674z",
      icon_viewbox: "0 0 24 24"
    },
    "salesforce" => %{
      name: "salesforce",
      display_name: "Salesforce",
      api_config_key: :salesforce_api,
      api_module: SocialScribe.SalesforceApi,
      field_labels: %{
        "firstname" => "First Name",
        "lastname" => "Last Name",
        "email" => "Email",
        "phone" => "Phone",
        "mobilephone" => "Mobile Phone",
        "jobtitle" => "Title",
        "department" => "Department",
        "address" => "Mailing Street",
        "city" => "City",
        "state" => "State",
        "zip" => "ZIP Code",
        "country" => "Country"
      },
      ai_field_descriptions:
        "- Phone numbers (phone, mobilephone)\n- Email addresses (email)\n- Job title/role (jobtitle)\n- Department (department)\n- Physical address details (address, city, state, zip, country)",
      ai_field_names:
        "firstname, lastname, email, phone, mobilephone, jobtitle, department, address, city, state, zip, country",
      modal_submit_text: "Update Salesforce",
      modal_submit_class: "bg-[#0070D2] hover:bg-[#005FB2]",
      button_class: "bg-[#0070D2] hover:bg-[#005FB2]",
      overlay_class: "bg-slate-500/90",
      modal_description:
        "Here are suggested updates to sync with your Salesforce CRM based on this meeting",
      uid_label: "Org ID",
      connect_button_class:
        "bg-[#0070D2] hover:bg-[#005FB2] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#0070D2]",
      icon_svg_path:
        "M10.09 2.45a4.94 4.94 0 0 0-3.81 1.81 5.96 5.96 0 0 0-4.52 5.73 5.96 5.96 0 0 0 4.14 5.67 4.43 4.43 0 0 0 4.18 2.99 4.44 4.44 0 0 0 2.91-1.1 4.44 4.44 0 0 0 3.39 1.57 4.48 4.48 0 0 0 4.34-3.39A4.96 4.96 0 0 0 24 11.2a4.97 4.97 0 0 0-4.48-4.95 5.44 5.44 0 0 0-4.97-3.8 5.46 5.46 0 0 0-3.13.98 4.92 4.92 0 0 0-1.33-.98z",
      icon_viewbox: "0 0 24 24"
    }
  }

  def all, do: Map.values(@providers)
  def get(name), do: Map.fetch!(@providers, name)
  def names, do: Map.keys(@providers)
end
