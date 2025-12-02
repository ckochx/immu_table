defmodule ImmuTableEx.LockTest do
  use ImmuTableEx.DataCase, async: false

  alias ImmuTableEx.Lock

  describe "with_lock/3" do
    test "acquires and releases advisory lock" do
      entity_id = UUIDv7.generate()

      result =
        Lock.with_lock(TestRepo, entity_id, fn ->
          :locked_operation_completed
        end)

      assert result == :locked_operation_completed
    end

    test "acquires lock successfully" do
      entity_id = UUIDv7.generate()

      result =
        Lock.with_lock(TestRepo, entity_id, fn ->
          :success
        end)

      assert result == :success
    end

    test "serializes concurrent access to same entity_id" do
      entity_id = UUIDv7.generate()
      parent = self()

      task1 =
        Task.async(fn ->
          Lock.with_lock(TestRepo, entity_id, fn ->
            send(parent, {:task1, :entered})
            Process.sleep(50)
            send(parent, {:task1, :exiting})
            :task1_done
          end)
        end)

      task2 =
        Task.async(fn ->
          Process.sleep(10)

          Lock.with_lock(TestRepo, entity_id, fn ->
            send(parent, {:task2, :entered})
            :task2_done
          end)
        end)

      assert_receive {:task1, :entered}, 100
      assert_receive {:task1, :exiting}, 100
      assert_receive {:task2, :entered}, 100

      assert Task.await(task1) == :task1_done
      assert Task.await(task2) == :task2_done
    end

    test "allows concurrent access to different entity_ids" do
      entity_id1 = UUIDv7.generate()
      entity_id2 = UUIDv7.generate()
      parent = self()

      task1 =
        Task.async(fn ->
          Lock.with_lock(TestRepo, entity_id1, fn ->
            send(parent, {:task1, :entered})
            Process.sleep(50)
            :task1_done
          end)
        end)

      task2 =
        Task.async(fn ->
          Process.sleep(10)

          Lock.with_lock(TestRepo, entity_id2, fn ->
            send(parent, {:task2, :entered})
            :task2_done
          end)
        end)

      assert_receive {:task1, :entered}, 100
      assert_receive {:task2, :entered}, 100

      assert Task.await(task1) == :task1_done
      assert Task.await(task2) == :task2_done
    end
  end
end
