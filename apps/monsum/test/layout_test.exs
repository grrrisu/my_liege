defmodule Monsum.LayoutTest do
  use ExUnit.Case
  import Phoenix.LiveViewTest

  alias Monsum.Layout

  test "show flash error" do
    flash = %{"error" => "An error message"}
    output = render_component(&Layout.flash/1, flash: flash)
    assert output =~ "Error"
    assert output =~ "An error message"
    refute output =~ "Info"
  end

  test "show flash info" do
    flash = %{"info" => "some information"}
    output = render_component(&Layout.flash/1, flash: flash)
    assert output =~ "Info"
    assert output =~ "some information"
    refute output =~ "Error"
  end

  test "don't show flash" do
    flash = %{}
    output = render_component(&Layout.flash/1, flash: flash)
    refute output =~ "Error"
    refute output =~ "Info"
  end
end
