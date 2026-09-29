module BBBEvents
  class RecordedSegment
    attr_accessor :start, :stop, :duration

    def initialize
      @stop = nil
      @duration = 0
    end

    def stop=(stop)
      @stop = stop
      @duration = (@stop - @start).to_i
    end

    def to_h
      hash = {}
      instance_variables.each { |var| hash[var[1..-1]] = instance_variable_get(var) }
      hash
    end

    def as_json
      {
        start: BBBEvents.format_datetime(@start),
        stop: BBBEvents.format_datetime(@stop),
        duration: @duration,
      }
    end

    def to_json
      JSON.generate(as_json)
    end
  end
end
