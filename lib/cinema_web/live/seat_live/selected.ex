defmodule CinemaWeb.SeatLive.Selected do
  use CinemaWeb, :live_view

  alias Cinema.{Repo, Halls, Seats}
  alias Cinema.Purchases.Purchase
  alias SendGrid.{Email, Mail}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(email: "")}
  end

  @impl true
  def handle_params(
    %{"hall_id" => hall_id, "selected_seats_data" => selected_seats_data},
    _,
    socket
  ) do
    hall = Halls.get_hall!(hall_id)

    IO.puts(socket.assigns.email)

    selected_seats_data =
      selected_seats_data
      |> String.split(",")
      |> Enum.map(
        fn x ->
          [id, row] = String.split(x, "|")

          %{seat: Seats.get_seat!(id), row: row}
        end
      )

    {
      :noreply,
      socket
      |> assign(:page_title, page_title(socket.assigns.live_action))
      |> assign(:hall, hall)
      |> assign(:selected_seats_data, selected_seats_data)
    }
  end

  @impl true
  def handle_event("buy-tickets", _, socket) do
    selected_seats_data = socket.assigns.selected_seats_data

    purchase = %Purchase{} |> Purchase.changeset(%{}) |> Repo.insert!()

    tickets = Enum.map(
      selected_seats_data,
      fn %{seat: seat, row: row_number} ->
        seat
        |> Seats.create_ticket!(
          purchase,
          %{row_number: String.to_integer(row_number)}
        )
        |> Repo.preload([:seat])
      end
    )

    mail =
      Email.build()
      |> Email.add_to(socket.assigns.email)
      |> Email.put_from("cinema@email")
      |> Email.put_subject("Tickets purchase")
      |> Email.put_phoenix_view(CinemaWeb.PurchaseView)
      |> Email.put_phoenix_template(
        "purchase.html",
        socket: socket,
        tickets: tickets
      )

    case Mail.send(mail) do
      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Email can't be sent. Check your address")}
      :ok ->
        {
          :noreply,
          socket
          |> push_redirect(
            to: Routes.seat_purchases_path(
              socket,
              :purchases,
              purchase.id
            )
          )
          |> put_flash(:info, "Tickets were successfully bought")
        }
    end
  end

  def handle_event("email-input", %{"value" => value}, socket) do
    IO.puts(value)

    {:noreply, assign(socket, email: value)}
  end

  defp page_title(:selected), do: "Selected seats"
end