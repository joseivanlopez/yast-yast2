#!/usr/bin/env rspec

require_relative "test_helper"
require "yast2/fs_snapshot"

describe Yast2::FsSnapshot do
  def logger
    described_class.log
  end

  FIND_CONFIG = "/usr/bin/snapper --no-dbus list-configs | grep \"^root \" >/dev/null"
  LIST_SNAPSHOTS = "LANG=en_US.UTF-8 /usr/bin/snapper --no-dbus list"

  describe ".configured?" do
    before do
      allow(Yast::SCR).to receive(:Execute)
        .with(path(".target.bash_output"), FIND_CONFIG)
        .and_return("stdout" => "", "exit" => find_code)
    end

    context "when snapper's configuration does not exist" do
      let(:find_code) { 1 }

      it "returns false" do
        expect(logger).to receive(:info).with(/Checking if Snapper is configured/)
        expect(described_class.configured?).to eq(false)
      end
    end

    context "when snapper's configuration exists" do
      let(:find_code) { 0 }

      it "returns false" do
        expect(described_class.configured?).to eq(true)
      end
    end
  end

  describe ".create_single" do
    CREATE_SINGLE_SNAPSHOT = "/usr/lib/snapper/installation-helper --step 5 "\
      "--snapshot-type single --description \"some-description\""

    before do
      allow(Yast2::FsSnapshot).to receive(:configured?).and_return(configured)
    end

    context "when snapper is configured" do
      let(:configured) { true }

      before do
        allow(Yast::SCR).to receive(:Execute)
          .with(path(".target.bash_output"), CREATE_SINGLE_SNAPSHOT)
          .and_return(output)
      end

      context "when snapshot creation fails" do
        let(:output) { { "stdout" => "", "exit" => 1 } }

        it "logs the error and returns nil" do
          expect(logger).to receive(:error).with(/Snapshot could not be created/)
          expect { described_class.create_single("some-description") }
            .to raise_error(Yast2::SnapshotCreationFailed)
        end
      end

      context "when snapshot creation is successful" do
        let(:output) { { "stdout" => "2", "exit" => 0 } }
        let(:dummy_snapshot) { double("snapshot") }

        it "returns the created snapshot" do
          expect(described_class).to receive(:find).with(2)
            .and_return(dummy_snapshot)
          snapshot = described_class.create_single("some-description")
          expect(snapshot).to be(dummy_snapshot)
        end
      end
    end

    context "when snapper is not configured" do
      let(:configured) { false }

      it "raises an exception" do
        expect { described_class.create_single("some-description") }
          .to raise_error(Yast2::SnapperNotConfigured)
      end
    end
  end

  describe ".create_pre" do
    CREATE_PRE_SNAPSHOT = "/usr/lib/snapper/installation-helper --step 5 "\
      "--snapshot-type pre --description \"some-description\""

    before do
      allow(Yast2::FsSnapshot).to receive(:configured?).and_return(configured)
    end

    context "when snapper is configured" do
      let(:configured) { true }

      before do
        allow(Yast::SCR).to receive(:Execute)
          .with(path(".target.bash_output"), CREATE_PRE_SNAPSHOT)
          .and_return(output)
      end

      context "when snapshot creation fails" do
        let(:output) { { "stdout" => "", "exit" => 1 } }

        it "logs the error and returns nil" do
          expect(logger).to receive(:error).with(/Snapshot could not be created/)
          expect { described_class.create_pre("some-description") }
            .to raise_error(Yast2::SnapshotCreationFailed)
        end
      end

      context "when snapshot creation is successful" do
        let(:output) { { "stdout" => "2", "exit" => 0 } }
        let(:dummy_snapshot) { double("snapshot") }

        it "returns the created snapshot" do
          expect(described_class).to receive(:find).with(2)
            .and_return(dummy_snapshot)
          snapshot = described_class.create_pre("some-description")
          expect(snapshot).to be(dummy_snapshot)
        end
      end
    end

    context "when snapper is not configured" do
      let(:configured) { false }

      it "raises an exception" do
        expect { described_class.create_pre("some-description") }
          .to raise_error(Yast2::SnapperNotConfigured)
      end
    end
  end

  describe ".create_post" do
    CREATE_POST_SNAPSHOT = "/usr/lib/snapper/installation-helper --step 5 "\
      "--snapshot-type post --description \"some-description\" --pre-num 2"

    before do
      allow(Yast2::FsSnapshot).to receive(:configured?).and_return(configured)
    end

    context "when snapper is configured" do
      let(:configured) { true }

      let(:post_snapshot) { double("snapshot", snapshot_type: :post, number: 3)}
      let(:pre_snapshot) { double("snapshot", snapshot_type: :pre, number: 2 )}
      let(:single_snapshot) { double("snapshot", snapshot_type: :single) }
      let(:dummy_snapshot) { double("snapshot") }
      let(:snapshots) { [ pre_snapshot ] }
      let(:output) { { "stdout" => "3", "exit" => 0 } }

      before do
        allow(Yast::SCR).to receive(:Execute)
          .with(path(".target.bash_output"), CREATE_POST_SNAPSHOT)
          .and_return(output)
        allow(Yast2::FsSnapshot).to receive(:all)
          .and_return(snapshots)
      end

      context "when snapshot creation fails" do
        let(:output) { { "stdout" => "", "exit" => 1 } }

        it "logs the error and raises an exception" do
          expect(logger).to receive(:error).with(/Snapshot could not be created/)
          expect { described_class.create_post("some-description") }
            .to raise_error(Yast2::SnapshotCreationFailed)
        end
      end

      context "when snapshot creation is successful" do
        it "returns the created snapshot" do
          expect(described_class).to receive(:find).with(3)
            .and_return(dummy_snapshot)
          snapshot = described_class.create_post("some-description")
          expect(snapshot).to be(dummy_snapshot)
        end
      end

      context "when the number of the previous snapshot is given" do
        context "when that snapshot exists" do
          let(:snapshots) { [pre_snapshot] }

          it "creates a 'post' snapshot matching the previous one" do
            allow(Yast2::FsSnapshot).to receive(:find).with(pre_snapshot.number)
              .and_return(pre_snapshot)
            expect(Yast2::FsSnapshot).to receive(:find).with(3)
              .and_return(dummy_snapshot)
            expect(described_class.create_post("some-description", pre_snapshot.number))
              .to be(dummy_snapshot)
          end
        end

        context "when that snapshot does not exist" do
          it "logs the error and raises an exception" do
            expect(logger).to receive(:error).with(/Previous filesystem snapshot was not found/)
            expect { described_class.create_post("some-description", 100) }
              .to raise_error(Yast2::PreviousSnapshotNotFound)
          end
        end
      end

      context "when the number of the previous snapshot is not given" do
        context "when last snapshot is of type 'pre'" do
          let(:snapshots) { [pre_snapshot] }

          it "creates a 'post' matching that 'pre'" do
            allow(Yast2::FsSnapshot).to receive(:find).with(pre_snapshot.number)
              .and_return(pre_snapshot)
            expect(Yast2::FsSnapshot).to receive(:find).with(3)
              .and_return(dummy_snapshot)
            expect(described_class.create_post("some-description"))
              .to be(dummy_snapshot)
          end
        end

        context "when last snapshot is of type 'post'" do
          let(:snapshots) { [pre_snapshot, post_snapshot] }

          it "raises and exception" do
            expect(logger).to receive(:error).with(/Previous filesystem snapshot was not found/)
            expect { described_class.create_post("some-description") }
              .to raise_error(Yast2::PreviousSnapshotNotFound)
          end
        end

        context "when last 'pre' is followed only by 'single' snapshots" do
          let(:snapshots) { [pre_snapshot, single_snapshot] }

          it "creates a 'post' matching that 'pre'" do
            allow(Yast2::FsSnapshot).to receive(:find).with(pre_snapshot.number)
              .and_return(pre_snapshot)
            expect(Yast2::FsSnapshot).to receive(:find).with(3)
              .and_return(dummy_snapshot)
            expect(described_class.create_post("some-description"))
              .to be(dummy_snapshot)
          end
        end
      end
    end

    context "when snapper is not configured" do
      let(:configured) { false }

      it "raises an exception" do
        expect { described_class.create_post("some-description") }
          .to raise_error(Yast2::SnapperNotConfigured)
      end
    end
  end

  describe ".all" do
    before do
      allow(Yast2::FsSnapshot).to receive(:configured?).and_return(configured)
    end

    context "when snapper is configured" do
      let(:configured) { true }
      let(:output) { File.read(output_path) }

      before do
        allow(Yast::SCR).to receive(:Execute)
          .with(path(".target.bash_output"), LIST_SNAPSHOTS)
          .and_return("stdout" => output, "exit" => 0)
      end

      context "given some snapshots exist" do
        let(:output_path) { File.expand_path("../fixtures/snapper-list.txt", __FILE__) }

        it "should return the snapshots and log about how many were found" do
          expect(logger).to receive(:info).with(/Retrieving snapshots list/)
          snapshots = described_class.all
          expect(snapshots).to be_kind_of(Array)
          expect(snapshots.size).to eq(5)
        end
      end

      context "given no snapshots exist" do
        let(:output_path) { File.expand_path("../fixtures/empty-snapper-list.txt", __FILE__) }

        it "should return an empty array" do
          expect(described_class.all).to eq([])
        end
      end
    end

    context "when snapper is not configured" do
      let(:configured) { false }

      it "raises an exception" do
        expect { described_class.all }
          .to raise_error(Yast2::SnapperNotConfigured)
      end
    end
  end

  describe ".find" do
    before do
      allow(Yast2::FsSnapshot).to receive(:configured?).and_return(configured)
    end

    context "when snapper is configured" do
      let(:configured) { true }
      let(:output) { File.read(output_path) }
      let(:output_path) { File.expand_path("../fixtures/snapper-list.txt", __FILE__) }

      before do
        allow(Yast::SCR).to receive(:Execute)
          .with(path(".target.bash_output"), LIST_SNAPSHOTS)
          .and_return("stdout" => output, "exit" => 0)
      end

      context "when a snapshot with that number exists" do
        it "should return the snapshot" do
          snapshot = described_class.find(4)
          expect(snapshot.number).to eq(4)
          expect(snapshot.snapshot_type).to eq(:post)
          expect(snapshot.previous_number).to eq(3)
          expect(snapshot.timestamp).to eq(DateTime.parse("Wed 13 May 2015 05:03:13 PM WEST"))
          expect(snapshot.user).to eq("root")
          expect(snapshot.cleanup_algo).to eq(:number)
          expect(snapshot.description).to eq("zypp(zypper)")
        end
      end

      context "when a snapshot with that number does not exists" do
        it "should return nil" do
          expect(described_class.find(100)).to be_nil
        end
      end
    end

    context "when snapper is not configured" do
      let(:configured) { false }

      it "raises an exception" do
        expect { described_class.find(1) }
          .to raise_error(Yast2::SnapperNotConfigured)
      end
    end
  end

  describe "#previous" do
    subject(:fs_snapshot) { described_class.new(1, :single, 10, DateTime.now, "root", "number", "") }
    let(:dummy_snapshot) { double("snapshot") }

    it "returns the previous snapshot" do
      expect(described_class).to receive(:find).with(10).and_return(dummy_snapshot)
      expect(fs_snapshot.previous).to eq(dummy_snapshot)
    end
  end
end
