require 'pry'

# rspec seems to complain about this class not having a #cause method; not sure
# why but this is a quick hacky fix just to get everything passing. it doesn't
# seem to affect the results of the tests anyway.
module Parslet
  class Cause
    def cause
      StandardError.new
    end
  end
end
