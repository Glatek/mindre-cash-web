defmodule MindreCash.SimpleServer do
  use Plug.Router
  require Logger

  # Import the Number.Currency module
  import Number.Currency

  plug(Plug.Static,
    at: "/",
    from: {:mindre_cash, "priv/static"},
    gzip: false
  )

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart],
    pass: ["*/*"]
  )

  plug(:match)
  plug(:dispatch)

  get "/" do
    # Get query parameter from URL
    query = conn.params["q"] || "mjölk"
    admin_key = System.get_env("ADMIN_KEY")

    # Fix the admin check to handle undefined admin parameter
    admin_param = conn.params["admin"]

    is_admin =
      admin_param != nil && admin_param == admin_key && admin_key != nil && admin_key != ""

    Logger.info("Processing request for query: #{query}, admin: #{is_admin}")

    try do
      # Fetch stores first
      stores_result = MindreCash.ApiClient.get_stores()

      # Then fetch products
      case MindreCash.ApiClient.search_products(query) do
        {:ok, products} ->
          Logger.info("API returned #{length(products)} products")

          # Get stores data
          stores =
            case stores_result do
              {:ok, stores_data} -> stores_data
              _ -> []
            end

          # Process the products for display with admin status and stores data
          {rows, savings_data, censored_count} =
            process_products_for_display(products, stores, query, is_admin)

          # Render the index page with the query results
          html = render_index(query, rows, savings_data, is_admin, censored_count)

          # Generate ETag manually
          etag = generate_etag(html)

          # Return full response with ETag
          conn
          |> put_resp_content_type("text/html")
          |> put_resp_header("etag", etag)
          |> put_resp_header("cache-control", "public, max-age=604800, immutable")
          |> put_resp_header("expires", get_next_sunday_23h59())
          |> send_resp(200, html)

        {:error, message} ->
          Logger.error("API error for query '#{query}': #{message}")
          fallback_response(conn, query)
      end
    rescue
      e ->
        Logger.error("Exception processing request: #{inspect(e)}")
        fallback_response(conn, query)
    end
  end

  defp fallback_response(conn, query) do
    html =
      render_index(
        query,
        sample_table_data(),
        %{
          amount: "3,50 kr",
          percent: "22",
          store: "Willys",
          unit: "liter"
        },
        false,
        2
      )

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  get "/search" do
    query = conn.params["query"] || conn.params["q"] || ""
    admin_param = if conn.params["admin"], do: "&admin=#{conn.params["admin"]}", else: ""

    if query && query != "" do
      conn
      |> put_resp_header("location", "/?q=#{URI.encode_www_form(query)}#{admin_param}")
      |> send_resp(302, "")
    else
      conn
      |> put_resp_header("location", "/")
      |> send_resp(302, "")
    end
  end

  get "/api/products" do
    # Sample data for the API endpoint
    products = [
      %{
        id: "milk",
        name: "Mjölk",
        prices: [
          %{store: "ICA", price: 16.90},
          %{store: "Coop", price: 17.50},
          %{store: "Willys", price: 15.90}
        ]
      },
      %{
        id: "bread",
        name: "Bröd",
        prices: [
          %{store: "ICA", price: 24.90},
          %{store: "Coop", price: 22.50},
          %{store: "Willys", price: 23.90}
        ]
      },
      %{
        id: "eggs",
        name: "Ägg (12-pack)",
        prices: [
          %{store: "ICA", price: 32.90},
          %{store: "Coop", price: 29.90},
          %{store: "Willys", price: 30.50}
        ]
      }
    ]

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(products))
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  defp render_index(query, rows, savings, is_admin \\ false, censored_count \\ 0) do
    """
    <!doctype html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="preconnect" href="https://fonts.googleapis.com">
            <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
            <link href="https://fonts.googleapis.com/css2?family=Public+Sans:ital,wght@0,100..900;1,100..900&display=swap" rel="stylesheet">
            <link rel="stylesheet" href="/css/style.css">
            <title>#{query} - Mindre.Cash</title>
        </head>
        <body>
            <header>
                #{render_logo()}
                <h1>Spendera <strong>mindre cash</strong> på <strong>#{query}</strong> i Arvika</h1>
                <p>Det billigaste priset på dina favoritvaror!</p>
            </header>
            <nav>
              <a href="?q=smör">Smör</a>
              <a href="?q=mjölk">Mjölk</a>
              <a href="?q=kaffe">Kaffe</a>
              <a href="?q=fläskfilé">Fläskfilé</a>
              <a href="?q=banan">Banan</a>
              <a href="?q=äpple%20royal%20gala">Äpple</a>
              <a href="?q=vitkål">Vitkål</a>
            </nav>
            #{render_savings(query, savings.unit, savings.amount, savings.percent, savings.store)}
            #{render_member_prompt(is_admin, censored_count)}
            #{render_table(rows)}
            <footer>
              <small>Ett projekt från <a href="https://glatek.se">Glatek</a></small>
            </footer>
            <script defer data-domain="mindre.cash" src="https://plausible.glate.ch/js/script.js"></script>
          </body>
        </html>
    """
  end

  defp render_savings(query, unit, savings_amount, savings_percent, store_name) do
    """
    <p>Du kan spara hela #{savings_amount}/#{unit} på #{query}.<br>Skillnaden mellan den billigaste och dyraste varan är <span class="savings">#{savings_percent} %</span>!</p>
    <p>Det billigaste priset på #{query} hittar du denna vecka på #{store_name}.</p>
    """
  end

  defp render_member_prompt(is_admin, count) do
    if is_admin do
      ""
    else
      """
      <p><div class="feedback feedback-warning">De #{count} billigaste varorna är gömda, men syns när du blir medlem.</div></p>
      """
    end
  end

  defp render_table(rows) do
    headers = ["", "Namn", "Kedja", "Styckpris", "Jämförelsepris"]

    table_headers =
      headers
      |> Enum.map(fn h -> "<th>#{h}</th>" end)
      |> Enum.join("")

    table_rows =
      rows
      |> Enum.map(fn cells ->
        cells_html =
          cells
          |> Enum.with_index()
          |> Enum.map(fn {cell, i} ->
            "<td data-label=\"#{Enum.at(headers, i)}\">#{cell}</td>"
          end)
          |> Enum.join("")

        "<tr>#{cells_html}</tr>"
      end)
      |> Enum.join("")

    """
        <table>
            <thead>
                <tr>
                    #{table_headers}
                </tr>
            </thead>
            <tbody>
                #{table_rows}
            </tbody>
        </table>
    """
  end

  defp sample_table_data do
    [
      ["1", "Arla Mellanmjölk 1,5%", "ICA", "16,90 kr", "16,90 kr/l"],
      ["2", "Garant Mellanmjölk 1,5%", "Willys", "15,90 kr", "15,90 kr/l"],
      ["3", "Coop Mellanmjölk 1,5%", "Coop", "17,50 kr", "17,50 kr/l"]
    ]
  end

  defp render_error(query, message) do
    """
    <!DOCTYPE html>
    <html lang="sv">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Fel - Mindre.Cash</title>
      <link rel="stylesheet" href="/css/style.css">
    </head>
    <body>
      <header>
        <h1>Mindre.Cash</h1>
        <p>Hitta billigaste stället för dina basvaror</p>
      </header>

      <main>
        <div class="feedback feedback-danger">
          <h2>Ett fel uppstod</h2>
          <p>Vi kunde inte söka efter "#{query}"</p>
          <p>Felmeddelande: #{message}</p>
        </div>

        <a href="/" class="back-link">Tillbaka till startsidan</a>
      </main>

      <footer>
        <p>© #{DateTime.utc_now().year} Mindre.Cash - En tjänst för att spara pengar på matvaror</p>
      </footer>
    </body>
    </html>
    """
  end

  defp process_products_for_display(products, stores, query, is_admin \\ false) do
    Logger.info("Processing products: #{length(products)} items with #{length(stores)} stores")

    # Create a map of store UUIDs to store names for quick lookup
    store_map =
      Enum.reduce(stores, %{}, fn store, acc ->
        Map.put(acc, store["uuid"], store["name"])
      end)

    # Handle empty products case
    if Enum.empty?(products) do
      Logger.info("No products found, using sample data")

      {sample_table_data(),
       %{
         amount: "0 kr",
         percent: "0",
         store: "Ingen data",
         unit: "st"
       }, 0}
    else
      # Filter items based on query
      filtered_products = filter_items(products, query)
      Logger.info("After filtering: #{length(filtered_products)} items")

      # Get the unit from the first product
      unit = (List.first(filtered_products) || %{})["unit"] || "st"

      # Find min and max unit prices - work with raw numbers
      min_unit_price =
        filtered_products
        |> Enum.map(fn product -> product["unit_price"] || product["item_price"] || 0 end)
        |> Enum.min(fn -> 0 end)

      max_unit_price =
        filtered_products
        |> Enum.map(fn product -> product["unit_price"] || product["item_price"] || 0 end)
        |> Enum.max(fn -> 0 end)

      # Calculate savings - keep as raw number until final formatting
      savings_amount_raw = max_unit_price - min_unit_price

      # Calculate percentage difference based on unit prices
      savings_percent =
        if min_unit_price > 0 do
          :erlang.float_to_binary((max_unit_price - min_unit_price) / min_unit_price * 100,
            decimals: 0
          )
        else
          "0"
        end

      # Find store with lowest unit price
      cheapest_store =
        if is_admin do
          # Find the store with the lowest unit price
          lowest_unit_price_product =
            filtered_products
            |> Enum.min_by(
              fn product -> product["unit_price"] || product["item_price"] || 0 end,
              fn -> %{} end
            )

          store_uuid = lowest_unit_price_product["store_uuid"]
          Map.get(store_map, store_uuid) || lowest_unit_price_product["store"] || "Unknown"
        else
          censor(12)
        end

      # Create table rows with raw price data for sorting
      rows_with_raw_prices =
        filtered_products
        |> Enum.with_index(1)
        |> Enum.map(fn {product, _index} ->
          # Get store name from the store map
          store_uuid = product["store_uuid"]
          store_name = Map.get(store_map, store_uuid) || product["store"] || "Unknown"

          # Create marks (organic, Swedish origin)
          marks_list = []

          marks_list =
            if product["organic"] do
              ["<span title=\"ekologisk\">🌱</span>" | marks_list]
            else
              marks_list
            end

          origin = product["country_of_origin"] || ""
          title = String.downcase(product["title"] || "")

          marks_list =
            if String.contains?(String.downcase(origin), "sweden") ||
                 String.contains?(String.downcase(origin), "sverige") ||
                 String.contains?(title, "svenskt") do
              ["<span title=\"från Sverige\">🇸🇪</span>" | marks_list]
            else
              marks_list
            end

          # Keep raw prices for sorting
          item_price = product["item_price"] || 0
          unit_price = product["unit_price"] || item_price

          # Store raw data for later formatting
          %{
            marks: Enum.join(marks_list, " "),
            title: product["title"] || "",
            store: store_name,
            item_price: item_price,
            unit_price: unit_price,
            unit: unit
          }
        end)
        |> Enum.sort_by(fn row -> row.unit_price end)

      # Handle censoring for non-admin users
      {final_rows_with_raw_prices, censored_count} =
        if is_admin do
          # Admin sees all rows
          {rows_with_raw_prices, 0}
        else
          # Calculate how many items to censor - half of the total
          count = floor(length(rows_with_raw_prices) / 2)

          # For non-admin, only show the more expensive half (drop the cheapest half)
          visible_rows = Enum.drop(rows_with_raw_prices, count)

          # Create a single censored row to show at the top
          censored_row = %{
            marks: censor(2),
            title: censor(12),
            store: censor(8),
            # Use censor instead of 0
            item_price: censor(6),
            # Use censor instead of 0
            unit_price: censor(6),
            unit: unit
          }

          # Add the censored row at the beginning of visible rows
          {[censored_row] ++ visible_rows, count}
        end

      # NOW format the currency for display - at the very last step
      formatted_rows =
        Enum.map(final_rows_with_raw_prices, fn row ->
          # Special handling for censored row
          if is_binary(row.item_price) && is_binary(row.unit_price) do
            # This is our censored row, use the censored values directly
            [
              row.marks,
              row.title,
              row.store,
              # Already censored
              row.item_price,
              "#{row.unit_price}/#{row.unit}"
            ]
          else
            # Normal row with numeric values
            [
              row.marks,
              row.title,
              row.store,
              format_currency(row.item_price),
              "#{format_currency(row.unit_price)}/#{row.unit}"
            ]
          end
        end)

      # Return the formatted rows, savings data with formatted amount, and censored count
      {formatted_rows,
       %{
         amount: format_currency(savings_amount_raw),
         percent: savings_percent,
         store: cheapest_store,
         unit: unit
       }, censored_count}
    end
  end

  defp get_next_sunday_23h59 do
    now = DateTime.utc_now()
    # 7 = Sunday in Elixir
    days_until_sunday = rem(7 - Date.day_of_week(now), 7)

    next_sunday =
      now
      |> DateTime.add(days_until_sunday * 24 * 60 * 60, :second)
      |> DateTime.truncate(:second)

    # Set time to 23:59:59
    next_sunday_23h59 = %{next_sunday | hour: 23, minute: 59, second: 59}

    # Format as HTTP date
    Calendar.strftime(next_sunday_23h59, "%a, %d %b %Y %H:%M:%S GMT")
  end

  @random_unicodes [
    "𜵐",
    "𜵑",
    "𜵒",
    "𜵓",
    "𜵔",
    "𜵕",
    "𜵖",
    "𜵗",
    "𜵘",
    "𜵙",
    "𜵚",
    "𜵛",
    "𜵜",
    "𜵝",
    "𜵞",
    "𜵟"
  ]

  defp get_random_unicode_letter do
    Enum.random(@random_unicodes)
  end

  defp censor(seed) do
    length = div(seed, 2) + :rand.uniform(seed - div(seed, 2))

    1..length
    |> Enum.map(fn _ -> get_random_unicode_letter() end)
    |> Enum.join("")
  end

  defp filter_items(items, query) do
    if Enum.empty?(items) do
      items
    else
      case query do
        "smör" ->
          Enum.filter(items, fn item ->
            !String.contains?(String.downcase(item["title"] || ""), "bredbart")
          end)

        "mjölk" ->
          Enum.filter(items, fn item ->
            !String.contains?(String.downcase(item["title"] || ""), "kaffe")
          end)

        "kaffe" ->
          Enum.filter(items, fn item -> item["unit"] == "kg" end)

        _ ->
          items
      end
    end
  end

  # Replace your format_currency functions with this one
  defp format_currency(amount) when is_integer(amount) do
    # Convert from öre to kronor for integers
    number_to_currency(amount, unit: "kr", precision: 2, delimiter: " ", separator: ",")
  end

  defp format_currency(amount) when is_float(amount) do
    # Format floats directly
    number_to_currency(amount, unit: "kr", precision: 2, delimiter: " ", separator: ",")
  end

  defp format_currency(_) do
    "0,00 kr"
  end

  defp generate_etag(content) when is_binary(content) do
    :crypto.hash(:md5, content) |> Base.encode16(case: :lower)
  end

  defp render_logo do
    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M14,18a1,1,0,0,0,1-1V15a1,1,0,0,0-2,0v2A1,1,0,0,0,14,18Zm-4,0a1,1,0,0,0,1-1V15a1,1,0,0,0-2,0v2A1,1,0,0,0,10,18ZM19,6H17.62L15.89,2.55a1,1,0,1,0-1.78.9L15.38,6H8.62L9.89,3.45a1,1,0,0,0-1.78-.9L6.38,6H5a3,3,0,0,0-.92,5.84l.74,7.46a3,3,0,0,0,3,2.7h8.38a3,3,0,0,0,3-2.7l.74-7.46A3,3,0,0,0,19,6ZM17.19,19.1a1,1,0,0,1-1,.9H7.81a1,1,0,0,1-1-.9L6.1,12H17.9ZM19,10H5A1,1,0,0,1,5,8H19a1,1,0,0,1,0,2Z"></path></svg>
    """
  end
end
