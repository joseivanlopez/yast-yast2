# encoding: utf-8

# Copyright (c) [2021] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"

module Yast2
  module Issues
    # Represents a problem detected by YaST.
    #
    # This class represents a generic error. Other classes can inherit from this one to add more
    # specific information. See {InvalidValue} as an example.
    #
    # @example Create a new error
    #   Issue.new("Could not read network configuration", severity: :fatal)
    #
    # @example Create an error from an specific location
    #   Issue.new(
    #     "Could not read the routing table",
    #     location: "file:/etc/sysconfig/ifroute-eth0",
    #     severity: :warn
    #   )
    class Issue
      include Yast::I18n

      # @return [String,nil] Where the error is located.
      attr_reader :location
      # @return [String] Error message
      attr_reader :message
      # @return [Symbol] Error severity (:warn, :fatal)
      attr_reader :severity

      # @param [URI,String,nil] Where the error is located. Use a URI or
      #   a string to represent the error location. Use 'nil' if it
      #   does not exist an specific location.
      def initialize(message, location: nil, severity: :warn)
        @message = message
        @location = location.to_s if location
        @severity = severity
      end

      # Determines whether the error is fatal or not
      #
      # @return [Boolean]
      def fatal?
        @severity == :fatal
      end
    end
  end
end
