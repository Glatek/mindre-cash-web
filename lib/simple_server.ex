defmodule SimpleServer do
  use Plug.Router

  plug(Plug.Static,
    at: "/",
    from: {:simple_server, "priv/static"},
    gzip: false
  )

  plug(:match)
  plug(:dispatch)

  get "/" do
    html = render_index()

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  get "/api/products" do
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

  defp render_index do
    """
    <!DOCTYPE html>
    <html lang="sv">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Mindre.Cash - Hitta billigaste stället för dina basvaror</title>
      <link rel="stylesheet" href="/css/style.css">
    </head>
    <body>
      <header>
        <h1>Mindre.Cash</h1>
        <p>Hitta billigaste stället för dina basvaror</p>
      </header>

      <main>
        <div id="product-container" class="product-list">
          <!-- Products will be loaded here -->
          <p>Laddar produkter...</p>
        </div>
      </main>

      <footer>
        <p>© #{DateTime.utc_now().year} Mindre.Cash - En tjänst för att spara pengar på matvaror</p>
      </footer>

      <script>
        document.addEventListener('DOMContentLoaded', async () => {
          try {
            const response = await fetch('/api/products');
            const products = await response.json();

            const container = document.getElementById('product-container');
            container.innerHTML = '';

            products.forEach(product => {
              // Find the lowest price
              const lowestPrice = Math.min(...product.prices.map(p => p.price));

              const productCard = document.createElement('div');
              productCard.className = 'product-card';

              const productName = document.createElement('h2');
              productName.className = 'product-name';
              productName.textContent = product.name;

              const priceList = document.createElement('ul');
              priceList.className = 'price-list';

              product.prices.forEach(price => {
                const priceItem = document.createElement('li');
                priceItem.className = 'price-item' + (price.price === lowestPrice ? ' best-price' : '');
                priceItem.innerHTML = `<span>${price.store}</span><span>${price.price.toFixed(2)} kr</span>`;
                priceList.appendChild(priceItem);
              });

              productCard.appendChild(productName);
              productCard.appendChild(priceList);
              container.appendChild(productCard);
            });
          } catch (error) {
            console.error('Error loading products:', error);
            document.getElementById('product-container').innerHTML = '<p>Kunde inte ladda produkter. Försök igen senare.</p>';
          }
        });
      </script>
    </body>
    </html>
    """
  end
end
