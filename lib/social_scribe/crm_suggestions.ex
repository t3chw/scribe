defmodule SocialScribe.CrmSuggestions do
  @moduledoc """
  Generates and formats CRM contact update suggestions by combining
  AI-extracted data with existing CRM contact information.
  Works with any CRM provider via crm_config.
  """

  alias SocialScribe.AIContentGeneratorApi
  alias SocialScribe.CrmApiBehaviour
  alias SocialScribe.Accounts.UserCredential

  @doc """
  Generates suggested updates for a CRM contact based on a meeting transcript.

  Returns a list of suggestion maps, each containing:
  - field: the CRM field name
  - label: human-readable field label
  - current_value: the existing value in CRM (or nil)
  - new_value: the AI-suggested value
  - context: explanation of where this was found in the transcript
  - apply: boolean indicating whether to apply this update (default true)
  """
  def generate_suggestions(%UserCredential{} = credential, contact_id, meeting, crm_config) do
    api = CrmApiBehaviour.impl(crm_config.name)

    with {:ok, contact} <- api.get_contact(credential, contact_id),
         {:ok, ai_suggestions} <-
           AIContentGeneratorApi.generate_crm_suggestions(
             meeting,
             contact.display_name,
             crm_config
           ) do
      suggestions =
        ai_suggestions
        |> Enum.map(fn suggestion ->
          field = suggestion.field
          current_value = get_contact_field(contact, field)

          %{
            field: field,
            label: Map.get(crm_config.field_labels, field, field),
            current_value: current_value,
            new_value: suggestion.value,
            context: suggestion.context,
            apply: true,
            has_change: current_value != suggestion.value
          }
        end)
        |> Enum.filter(fn s -> s.has_change end)

      {:ok, %{contact: contact, suggestions: suggestions}}
    end
  end

  @doc """
  Generates suggestions without fetching contact data.
  Useful when contact hasn't been selected yet.
  """
  def generate_suggestions_from_meeting(meeting, contact_name, crm_config) do
    case AIContentGeneratorApi.generate_crm_suggestions(meeting, contact_name, crm_config) do
      {:ok, ai_suggestions} ->
        suggestions =
          ai_suggestions
          |> Enum.map(fn suggestion ->
            %{
              field: suggestion.field,
              label: Map.get(crm_config.field_labels, suggestion.field, suggestion.field),
              current_value: nil,
              new_value: suggestion.value,
              context: Map.get(suggestion, :context),
              timestamp: Map.get(suggestion, :timestamp),
              apply: true,
              has_change: true
            }
          end)

        {:ok, suggestions}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Merges AI suggestions with contact data to show current vs suggested values.
  """
  def merge_with_contact(suggestions, contact) when is_list(suggestions) do
    Enum.map(suggestions, fn suggestion ->
      current_value = get_contact_field(contact, suggestion.field)

      %{
        suggestion
        | current_value: current_value,
          has_change: current_value != suggestion.new_value,
          apply: true
      }
    end)
    |> Enum.filter(fn s -> s.has_change end)
  end

  defp get_contact_field(contact, field) when is_map(contact) do
    field_atom = String.to_existing_atom(field)
    Map.get(contact, field_atom)
  rescue
    ArgumentError -> nil
  end

  defp get_contact_field(_, _), do: nil
end
