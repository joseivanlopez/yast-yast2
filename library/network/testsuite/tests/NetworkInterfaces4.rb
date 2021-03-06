# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2002 - 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
# ***************************************************************************
module Yast
  # inject NetworkInterfaces accessor so we can modify Devices
  class NetworkInterfacesClass < Module
    attr_accessor :OriginalDevices
  end

  class NetworkInterfaces4Client < Client
    def main
      # bug 72164

      Yast.include self, "testsuite.rb"

      @READ = {
        "network" => {
          "section" => { "eth4" => nil },
          "value"   => {
            "eth4" => { "BOOTPROTO" => "dhcp", "NAME" => "we like 'singles'" }
          }
        },
        "probe"   => { "system" => [] },
        "target"  => { "tmpdir" => "/tmp" }
      }

      @EXEC = {
        "target" => {
          "bash_output" => { "exit" => 0, "stdout" => "", "stderr" => "" }
        }
      }

      TESTSUITE_INIT([@READ, {}, @EXEC], nil)
      Yast.import "NetworkInterfaces"

      DUMP("NetworkInterfaces::Read")
      TEST(->() { NetworkInterfaces.Read }, [@READ, {}, @EXEC], nil)
      NetworkInterfaces.OriginalDevices = nil

      DUMP("NetworkInterfaces::Write")
      TEST(->() { NetworkInterfaces.Write("") }, [@READ], nil)

      nil
    end
  end
end

Yast::NetworkInterfaces4Client.new.main
