defmodule Monsum.Layout do
  import Phoenix.Component

  def flash(assigns) do
    ~H"""
    <div :if={live_flash(@flash, :error)}
      class="flex gap-4 bg-red-100 p-4 rounded-md mb-5"
      phx-click="lv:clear-flash"
      phx-value-key="error"
      role="alert">
      <div class="w-max">
        <div class="h-10 w-10 flex rounded-full bg-gradient-to-b from-red-300 to-red-400 text-red-800">
          <i class="mx-auto pt-1 las la-exclamation-triangle la-2x"></i>
        </div>
      </div>
      <div class="space-y-1">
        <h6 class="font-bold text-red-800">Error</h6>
        <p class="text-sm text-red-700 leading-tight"><%= live_flash(@flash, :error) %></p>
      </div>
    </div>

    <div :if={live_flash(@flash, :info)}
      class="flex gap-4 bg-sky-100 p-4 rounded-md mb-5"
      phx-click="lv:clear-flash"
      phx-value-key="info"
      role="alert">
      <div class="w-max">
        <div class="h-10 w-10 flex rounded-full bg-gradient-to-b from-sky-300 to-sky-400 text-sky-700">
          <i class="mx-auto pt-1 las la-info la-2x"></i>
        </div>
      </div>
      <div class="space-y-1">
        <h6 class="font-bold text-sky-800">Info</h6>
        <p class="text-sm text-sky-700 leading-tight"><%= live_flash(@flash, :info) %></p>
      </div>
    </div>
    """
  end
end
