

module BBBEvents
  class TransferAttendee < Attendee
    def initialize(join_event)
      super(join_event)

      @engagement = {
        questions: 0,
      }
    end
  end
end
