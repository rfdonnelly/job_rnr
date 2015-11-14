module AV
  module Jobs
    module Job
      class Slots
        def initialize(num_slots)
          @num_slots = num_slots
          @next_slot = num_slots
          @slots = *(0..(num_slots - 1))
        end

        def allocate
          @slots.shift
        end

        def size
          @num_slots
        end

        def available
          @slots.size
        end

        def free(slot)
          @slots.push(slot)
        end

        def reserve(slot)
          @slots.push(@next_slot)
          @next_slot += 1
        end
      end
    end
  end
end
