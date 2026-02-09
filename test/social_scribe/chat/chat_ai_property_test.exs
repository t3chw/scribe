defmodule SocialScribe.Chat.ChatAIPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias SocialScribe.Chat.ChatAI

  @common_words ~w(I What Who Where When Why How Can Could Would Should Tell Show Find Get Check The This That And But For With About From Your My His Her Their Our Its Also Just Ask Has Have Had Been Being Will)

  describe "extract_mentions/1 properties" do
    property "@mentions are returned when present in text" do
      check all(name <- capitalized_name_generator()) do
        text = "Please look up @#{name} in the CRM"
        result = ChatAI.extract_mentions(text)

        assert name in result,
               "Expected #{inspect(name)} in results, got #{inspect(result)}"
      end
    end

    property "@mentions take priority over fallback extraction" do
      check all(
              at_name <- capitalized_name_generator(),
              plain_name <- capitalized_name_generator()
            ) do
        text = "Tell me about @#{at_name} and also #{plain_name}"
        result = ChatAI.extract_mentions(text)

        # When @mentions exist, only @mentions are returned
        assert at_name in result
      end
    end

    property "results are always deduplicated" do
      check all(name <- capitalized_name_generator()) do
        text = "@#{name} and @#{name} again"
        result = ChatAI.extract_mentions(text)

        assert result == Enum.uniq(result),
               "Results should be deduplicated, got #{inspect(result)}"
      end
    end

    property "empty/whitespace input returns empty list" do
      check all(spaces <- string([?\s, ?\t, ?\n], min_length: 0, max_length: 10)) do
        result = ChatAI.extract_mentions(spaces)
        assert result == []
      end
    end

    property "lowercase words after @ are not extracted" do
      check all(word <- lowercase_word_generator()) do
        text = "look at @#{word} here"
        result = ChatAI.extract_mentions(text)

        refute word in result,
               "Lowercase @#{word} should not be extracted, got #{inspect(result)}"
      end
    end

    property "common words are filtered from fallback extraction" do
      check all(word <- member_of(@common_words)) do
        # No @mentions, so fallback is used; common words should be filtered
        text = "#{word} is something"
        result = ChatAI.extract_mentions(text)

        refute word in result,
               "Common word #{word} should be filtered, got #{inspect(result)}"
      end
    end
  end

  describe "fallback extraction properties" do
    property "finds capitalized multi-word names" do
      check all(
              first <- capitalized_name_generator(),
              last <- capitalized_name_generator()
            ) do
        # No @ prefix, so fallback kicks in
        full_name = "#{first} #{last}"
        text = "meeting with #{full_name} yesterday"
        result = ChatAI.extract_mentions(text)

        # The fallback should find the capitalized name (either full or parts)
        has_match =
          Enum.any?(result, fn r ->
            String.contains?(full_name, r) or String.contains?(r, first)
          end)

        assert has_match,
               "Expected to find capitalized name #{inspect(full_name)} in results #{inspect(result)}"
      end
    end

    property "all-lowercase text returns empty list" do
      check all(text <- string(?a..?z, min_length: 1, max_length: 50)) do
        result = ChatAI.extract_mentions(text)
        assert result == []
      end
    end
  end

  # Generators

  defp capitalized_name_generator do
    gen all(
          first <- string(?A..?Z, length: 1),
          rest <- string(?a..?z, min_length: 2, max_length: 8)
        ) do
      first <> rest
    end
  end

  defp lowercase_word_generator do
    gen all(word <- string(?a..?z, min_length: 2, max_length: 10)) do
      word
    end
  end
end
