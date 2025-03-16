defmodule MindreCash.ApiClient do
  @moduledoc """
  Client for making external API requests
  """
  require Logger
  use HTTPoison.Base

  defp supabase_url do
    Application.get_env(:mindre_cash, :supabase)[:url] ||
      raise "Supabase URL not configured. Check your config/runtime.exs file."
  end

  # Helper function to get the Supabase key from application config
  defp supabase_key do
    Application.get_env(:mindre_cash, :supabase)[:key] ||
      raise "Supabase key not configured. Check your config/runtime.exs file."
  end

  @doc """
  Get all stores from the API

  ## Examples

      iex> MindreCash.ApiClient.get_stores()
      {:ok, [%{"id" => 1, "name" => "ICA"}, %{"id" => 2, "name" => "Coop"}]}

  """
  def get_stores do
    # Log the request details for debugging
    Logger.info("Fetching all stores")

    # Get configuration
    url = supabase_url()
    key = supabase_key()

    # Set up headers
    headers = [
      {"Authorization", "Bearer #{key}"},
      {"apikey", key},
      {"Content-Type", "application/json"}
    ]

    # Build query parameters
    params = [
      {"select", "*"}
    ]

    # Convert params to URL query string
    query_string = URI.encode_query(params)

    # Construct the full URL
    full_url = "#{url}/rest/v1/stores?#{query_string}"
    Logger.info("Making request to: #{full_url}")

    # Wrap the HTTP request in a try/rescue block to catch all errors
    try do
      case get(full_url, headers) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          decoded = Jason.decode!(body)
          Logger.info("API returned #{length(decoded)} stores")
          {:ok, decoded}

        {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
          Logger.error("API error: #{status_code} - #{body}")
          {:error, "API error: #{status_code} - #{body}"}

        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.error("Network error: #{reason}")
          {:error, "Network error: #{reason}"}
      end
    rescue
      e ->
        Logger.error("Exception during API request: #{inspect(e)}")
        {:error, "Exception during API request: #{inspect(e)}"}
    end
  end

  @doc """
  Search for products based on a query string
  """
  def search_products(query) do
    # Log the request details for debugging
    Logger.info("Searching for products with query: #{query}")

    # Get configuration
    url = supabase_url()
    key = supabase_key()

    Logger.info("Using Supabase URL: #{url}")

    # Set up headers
    headers = [
      {"Authorization", "Bearer #{key}"},
      {"apikey", key},
      {"Content-Type", "application/json"}
    ]

    # Build query parameters
    params = [
      {"select", "*"},
      {"q", "eq.#{query}"}
    ]

    # Convert params to URL query string
    query_string = URI.encode_query(params)

    # Construct the full URL
    full_url = "#{url}/rest/v1/items?#{query_string}"
    Logger.info("Making request to: #{full_url}")

    # Wrap the HTTP request in a try/rescue block to catch all errors
    try do
      case get(full_url, headers) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          decoded = Jason.decode!(body)
          Logger.info("API returned: #{inspect(decoded)}")
          {:ok, decoded}

        {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
          Logger.error("API error: #{status_code} - #{body}")
          {:error, "API error: #{status_code} - #{body}"}

        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.error("Network error: #{reason}")
          {:error, "Network error: #{reason}"}
      end
    rescue
      e ->
        Logger.error("Exception during API request: #{inspect(e)}")
        {:error, "Exception during API request: #{inspect(e)}"}
    end
  end
end
