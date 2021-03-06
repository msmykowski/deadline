defmodule DeadlineTest do
  use ExUnit.Case
  doctest Deadline

  test "allows users to set deadlines" do
    us = self()
    spawn(fn ->
      Deadline.set(800)

      Deadline.work(fn ->
        send(us, :job1)
        :timer.sleep(500)
      end)

      Deadline.work(fn ->
        send(us, :job2)
        :timer.sleep(200)
      end)

      :timer.sleep(300)

      Deadline.work(fn ->
        send(us, :job3)
      end)

      send(us, :cleanup)
    end)

    assert_receive :job1, 1_000
    assert_receive :job2, 1_000
    assert_receive :cleanup, 1_000
    refute_receive :job3, 1_000
  end

  test "returns the result of the function" do
    Deadline.set(100)

    result = Deadline.work(fn ->
      :ok
    end)

    assert result == :ok
  end

  test "deadline contexts can be shared across process boundaries" do
    us = self()
    Deadline.set(100)
    ctx = Deadline.get()

    spawn(fn ->
      Deadline.set(ctx)
      send(us, {:ctx, Deadline.get()})
    end)

    assert_receive {:ctx, ^ctx}
  end

  test "working for longer than the deadline causes an exit" do
    Process.flag(:trap_exit, true)

    Deadline.set(100)
    Deadline.work(fn ->
      :timer.sleep(500)
    end)

    assert_receive {:EXIT, _, :canceled}
  end

  test "timers are canceled after work is completed" do
    Process.flag(:trap_exit, true)

    Deadline.set(10)
    Deadline.work(fn ->
      :ok
    end)

    refute_receive {:EXIT, _, :canceled}, 20
  end

  test "executes functions even if the deadline isn't set" do
    assert Deadline.work(fn -> :ok end) == :ok
  end

  test "returns the time_remaining" do
    Deadline.set(5_000)
    remaining = Deadline.time_remaining()
    assert 0 < remaining && remaining < 5_000

    :timer.sleep(100)

    new_remaining = Deadline.time_remaining(:millisecond)
    assert 0 < new_remaining && new_remaining < remaining
  end

  test "time_remaining/1 returns infinity if there is no deadline set" do
    assert Deadline.time_remaining == :infinity
  end

  test "can determine if a deadline has been reached" do
    # If no deadline has been set then we should return false
    assert Deadline.reached?() == false

    Deadline.set(10)
    assert Deadline.reached?() == false
    :timer.sleep(20)
    assert Deadline.reached?() == true
  end

  test "doesn't explode if there is no deadline context set" do
    ctx = Deadline.get()
    assert Deadline.set(ctx) == nil
    assert Deadline.time_remaining == :infinity
    assert Deadline.reached? == false
  end

  test "time_remaining/1 always returns 0 if the deadline has been exceeded" do
    Deadline.set(10)
    :timer.sleep(20)
    assert Deadline.time_remaining() == 0
  end
end
