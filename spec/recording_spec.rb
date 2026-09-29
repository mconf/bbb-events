require "spec_helper"

RSpec.describe BBBEvents::Recording do
  context "#metadata" do
    it "should properly parse metadata." do
      # Attribute names are kept as they are in events.xml
      expect(@sample.metadata).to eql({
        "gl-listed" => "false",
        "isBreakout" => "false",
        "meetingName" => "Home Room",
        "meetingId" => "ae5e285551844c61c757f4c8f233850a2e0b16bf",
      })
    end
  end

  context "#meeting_id" do
    it "should properly parse meeting_id." do
      expect(@sample.meeting_id).to eql("ae5e285551844c61c757f4c8f233850a2e0b16bf")
    end
  end

  context "#timestamp" do
    it "should properly parse timestamp." do
      expect(@sample.timestamp).to eql(1534433961829)
    end
  end

  context "#start" do
    it "should properly parse start time." do
      expect(@sample.start).to eql(Time.new(2018, 8, 16, 11, 39, 21, "-04:00"))
    end
  end

  context "#finish" do
    it "should properly parse finish time." do
      expect(@sample.finish).to eql(Time.new(2018, 8, 16, 11, 40, 58, "-04:00"))
    end
  end

  context "#duration" do
    it "should properly parse duration." do
      expect(@sample.duration).to eql(97)
    end
  end

  context "#attendees" do
    it "should be an Array." do
      expect(@sample.moderators).to be_an(Array)
    end

    it "should properly parse list of attendees." do
      expect(@sample.attendees).to all(be_an_instance_of(BBBEvents::Attendee))
    end
  end

  context "#moderators" do
    it "should be an Array." do
      expect(@sample.moderators).to be_an(Array)
    end

    it "should filter moderators from attendees." do
      @sample.moderators.each do |att|
        expect(att.moderator?).to be true
      end
    end
  end

  context "#viewers" do
    it "should be an Array." do
      expect(@sample.viewers).to be_an(Array)
    end

    it "should filter viewers from attendees." do
      @sample.viewers.each do |att|
        expect(att.moderator?).to be false
      end
    end
  end

  context "#polls" do
    it "should be an Array." do
      expect(@sample.polls).to be_an(Array)
    end

    it "should properly parse list of polls." do
      expect(@sample.polls).to all(be_an_instance_of(BBBEvents::Poll))
    end
  end

  context "#published_polls" do
    it "should be an Array." do
      expect(@sample.published_polls).to be_an(Array)
    end

    it "should filter published polls from polls." do
      @sample.published_polls.each do |poll|
        expect(poll.published?).to be true
      end
    end
  end

  context "#unpublished_polls" do
    it "should be an Array." do
      expect(@sample.unpublished_polls).to be_an(Array)
    end

    it "should filter unpublished polls from polls." do
      @sample.unpublished_polls.each do |poll|
        expect(poll.published?).to be false
      end
    end
  end

  context "#recorded_segments" do
    it "should be an Array." do
      expect(@sample.recorded_segments).to be_an(Array)
    end

    it "should not be empty." do
      expect(@sample.recorded_segments.length).to eql(1)
    end

    it "should properly parse start of recorded segment." do
      expect(@sample.recorded_segments.first.start).to eql(Time.new(2018, 8, 16, 11, 39, 47, "-04:00"))
    end

    it "should properly parse stop of recorded segment." do
      expect(@sample.recorded_segments.first.stop).to eql(Time.new(2018, 8, 16, 11, 40, 54, "-04:00"))
    end

    it "should determine recorded segment duration." do
      expect(@sample.recorded_segments.first.duration).to eql(67)
    end

    # Parses an events.xml with the given RecordStatusEvents, as [timestamp, status]
    # pairs, for a meeting that starts at 2017-07-14 02:40:00 UTC and lasts 9s.
    def recording_with_statuses(*statuses)
      events = statuses.map do |timestamp, status|
        %(<event timestamp="#{timestamp}" module="PARTICIPANT" eventname="RecordStatusEvent"><userId>w_1</userId><status>#{status}</status></event>)
      end
      file = Tempfile.new(["events", ".xml"])
      file.write(<<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <recording meeting_id="abc-1500000000000" bbb_version="2.6.0">
          <metadata meetingId="abc" meetingName="Test"/>
          <meeting id="abc-1500000000000" externalId="abc" name="Test" breakout="false"/>
          <event timestamp="0" module="PARTICIPANT" eventname="ParticipantJoinEvent"><userId>w_1</userId><externalUserId>u1</externalUserId><name>User</name><role>MODERATOR</role></event>
          #{events.join("\n")}
          <event timestamp="9000" module="PARTICIPANT" eventname="EndAndKickAllEvent"/>
        </recording>
      XML
      file.close
      BBBEvents.parse(file.path)
    ensure
      file&.unlink
    end

    it "should ignore a start while recording and a stop while not recording." do
      recording = recording_with_statuses([500, false], [1000, true], [2000, true], [4000, false], [5000, false], [7000, true])

      meeting_start = Time.parse("2017-07-14 02:40:00 UTC")
      expect(recording.recorded_segments.map { |s| [s.start - meeting_start, s.stop - meeting_start] }).to eql([[1.0, 4.0], [7.0, 9.0]])
      expect(recording.recorded_segments.map(&:duration)).to eql([3, 2])
    end

    it "should include recorded segments in the recording JSON." do
      segment = JSON.parse(@sample.to_json)["recorded_segments"].first

      expect(segment["start"]).to match(/\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}[+-]\d\d:\d\d\z/)
      expect(Time.parse(segment["start"])).to eql(Time.parse("2018-08-16 15:39:47 UTC"))
      expect(Time.parse(segment["stop"])).to eql(Time.parse("2018-08-16 15:40:54 UTC"))
      expect(segment["duration"]).to eql(67)
    end
  end

  context "#files" do
    it "should properly parse uploaded file names." do
      expect(@sample.files).to contain_exactly("default.pdf")
    end
  end

  context "#create_csv" do
    before(:all) do
      @csv_path = File.dirname(__FILE__) + "/testing.csv"
      @sample.create_csv(@csv_path)
    end

    after(:all) do
      File.delete(@csv_path) if File.exist?(@csv_path)
    end

    it "should generate csv file." do
      expect(File).to exist(@csv_path)
    end

    it "should include corrent number of polls." do
      written_polls = CSV.read(@csv_path).first.select { |h| h[/Poll \d/] }.length
      expect(written_polls).to eql(@sample.polls.length)
    end

    it "should write correct data." do
      first_user = CSV.read(@csv_path)[1]
      csv_row = @sample.attendees.first.csv_row
      expect(csv_row).to eql(first_user[0...csv_row.length])
    end
  end

  context "#user duration calculations" do
    it "should calculate user duration and return 2145" do
      joins = ["2020-10-26 08:16:52 +0000", "2020-10-26 08:27:43 +0000", "2020-10-26 08:28:25 +0000"]
      leaves = ["2020-10-26 08:26:55 +0000", "2020-10-26 08:28:25 +0000", "2020-10-26 08:53:25 +0000"]

      joins_formatted = []
      joins.each { |j| joins_formatted.append(Time.parse(j))}

      leaves_formatted = []
      leaves.each { |j| leaves_formatted.append(Time.parse(j))}

      expect(@sample.calculate_user_duration(joins_formatted, leaves_formatted)).to eql(2145)
    end

    it "should calculate user duration and return 2977" do
      joins = ["2020-10-26 08:06:18 +0000", "2020-10-26 08:09:08 +0000", "2020-10-26 08:10:47 +0000", "2020-10-26 08:12:24 +0000", "2020-10-26 08:13:10 +0000"]
      leaves = ["2020-10-26 08:10:35 +0000", "2020-10-26 08:12:05 +0000", "2020-10-26 08:13:05 +0000", "2020-10-26 08:53:35 +0000", "2020-10-26 08:56:31 +0000"]

      joins_formatted = []
      joins.each { |j| joins_formatted.append(Time.parse(j))}

      leaves_formatted = []
      leaves.each { |j| leaves_formatted.append(Time.parse(j))}

      expect(@sample.calculate_user_duration(joins_formatted, leaves_formatted)).to eql(2977)
    end

    it "should calculate user duration and return 249" do
      joins = ["2020-10-26 08:49:25 +0000", "2020-10-26 08:49:53 +0000", "2020-10-26 08:56:12 +0000"]
      leaves = ["2020-10-26 08:49:55 +0000", "2020-10-26 08:53:15 +0000", "2020-10-26 08:56:31 +0000"]

      joins_formatted = []
      joins.each { |j| joins_formatted.append(Time.parse(j))}

      leaves_formatted = []
      leaves.each { |j| leaves_formatted.append(Time.parse(j))}

      expect(@sample.calculate_user_duration(joins_formatted, leaves_formatted)).to eql(249)
    end

    it "should calculate user duration and return 3092" do
      joins = ["2020-10-26 08:04:51 +0000", "2020-10-26 08:05:37 +0000", "2020-10-26 08:06:26 +0000", "2020-10-26 08:06:28 +0000", "2020-10-26 08:07:20 +0000", "2020-10-26 08:08:03 +0000", "2020-10-26 08:17:43 +0000", "2020-10-26 08:53:50 +0000"]
      leaves = ["2020-10-26 08:07:55 +0000", "2020-10-26 08:56:31 +0000"]

      joins_formatted = []
      joins.each { |j| joins_formatted.append(Time.parse(j))}

      leaves_formatted = []
      leaves.each { |j| leaves_formatted.append(Time.parse(j))}

      expect(@sample.calculate_user_duration(joins_formatted, leaves_formatted)).to eql(3092)
    end
  end

  context "#duration calculations based on userid" do
    it "should calculate user duration and return 135 seconds" do
      sessions = {"w_fgwzlytmwbgi" =>
                    { :joins =>
                        [
                          { :timestamp => Time.parse("2020-10-26 08:54:16 +0000"),
                            :userid => "w_fgwzlytmwbgi",
                            :ext_userid => "39566",
                            :event => :join
                            }
                        ],
                      :lefts => []
                    }
                }

      finish = Time.parse("2020-10-26 08:56:31 +0000")

      expect(@sample.calculate_user_duration_based_on_userid(finish, sessions)).to eql(135)
    end

    it "should calculate user duration and return 6598 seconds" do
      sessions = {
                    "w_zgljgd7tuijf" =>
                      {
                        :joins =>
                          [
                            { :timestamp => Time.parse("2020-11-16 17:29:43 +0000"),
                              :userid => "w_zgljgd7tuijf",
                              :ext_userid => "4561",
                              :event => :join
                            },
                            { :timestamp => Time.parse("2020-11-16 18:09:37 +0000"),
                              :userid => "w_zgljgd7tuijf",
                              :ext_userid => "4561",
                              :event => :join
                            },
                            { :timestamp => Time.parse("2020-11-16 18:14:43 +0000"),
                              :userid => "w_zgljgd7tuijf",
                              :ext_userid => "4561",
                              :event => :join
                            }
                          ],
                        :lefts =>
                          [
                            { :timestamp => Time.parse("2020-11-16 18:03:02 +0000"),
                              :userid => "w_zgljgd7tuijf",
                              :ext_userid => "4561",
                              :event => :left
                            },
                            { :timestamp => Time.parse("2020-11-16 18:10:42 +0000"),
                              :userid => "w_zgljgd7tuijf",
                              :ext_userid => "4561",
                              :event => :left
                            },
                            { :timestamp => Time.parse("2020-11-16 18:15:32 +0000"),
                              :userid => "w_zgljgd7tuijf",
                              :ext_userid => "4561",
                              :event => :left
                            }
                          ]
                        },
                      "w_wbmrqo72jnjo" =>
                        {
                          :joins =>
                            [
                              { :timestamp => Time.parse("2020-11-16 18:01:34 +0000"),
                                :userid => "w_wbmrqo72jnjo",
                                :ext_userid => "4561",
                                :event => :join
                              },
                              { :timestamp => Time.parse("2020-11-16 19:11:28 +0000"),
                                :userid => "w_wbmrqo72jnjo",
                                :ext_userid => "4561",
                                :event => :join
                              },
                              { :timestamp => Time.parse("2020-11-16 19:14:47 +0000"),
                                :userid => "w_wbmrqo72jnjo",
                                :ext_userid => "4561",
                                :event => :join
                              },
                              { :timestamp => Time.parse("2020-11-16 19:16:12 +0000"),
                                :userid => "w_wbmrqo72jnjo",
                                :ext_userid => "4561",
                                :event => :join
                              },
                              { :timestamp => Time.parse("2020-11-16 19:18:02 +0000"),
                                :userid => "w_wbmrqo72jnjo",
                                :ext_userid => "4561",
                                :event => :join
                              }
                            ],
                          :lefts =>
                            [
                              { :timestamp => Time.parse("2020-11-16 19:10:52 +0000"),
                                :userid => "w_wbmrqo72jnjo",
                                :ext_userid => "4561",
                                :event => :left
                              },
                              { :timestamp => Time.parse("2020-11-16 19:14:32 +0000"),
                                :userid => "w_wbmrqo72jnjo",
                                :ext_userid => "4561",
                                :event => :left
                              },
                              { :timestamp => Time.parse("2020-11-16 19:15:42 +0000"),
                                :userid => "w_wbmrqo72jnjo",
                                :ext_userid => "4561",
                                :event => :left
                              },
                              { :timestamp => Time.parse("2020-11-16 19:17:02 +0000"),
                                :userid => "w_wbmrqo72jnjo",
                                :ext_userid => "4561",
                                :event => :left
                              },
                              { :timestamp => Time.parse("2020-11-16 19:22:02 +0000"),
                                :userid => "w_wbmrqo72jnjo",
                                :ext_userid => "4561",
                                :event => :left
                              }
                            ]
                        },
                      "w_tkerwwfgsede" =>
                        {
                          :joins =>
                            [
                              { :timestamp => Time.parse("2020-11-16 19:18:05 +0000"),
                                :userid => "w_tkerwwfgsede",
                                :ext_userid => "4561",
                                :event => :join
                              }
                            ],
                          :lefts =>
                            [
                              { :timestamp => Time.parse("2020-11-16 19:21:12 +0000"),
                                :userid => "w_tkerwwfgsede",
                                :ext_userid => "4561",
                                :event => :left
                              }
                            ]
                        }
                    }

      finish = Time.parse("2020-11-16 19:23:12 +0000")

      expect(@sample.calculate_user_duration_based_on_userid(finish, sessions)).to eql(6598)
    end

    it "should calculate user duration and return 6735 seconds" do
      sessions = {
                    "w_awh9rd167wx5" =>
                      {
                        :joins =>
                          [
                            { :timestamp => Time.parse("2020-11-16 17:28:56 +0000"),
                              :userid => "w_awh9rd167wx5",
                              :ext_userid => "4310",
                              :event => :join
                            }
                          ],
                        :lefts =>
                          [
                            { :timestamp => Time.parse("2020-11-16 17:29:42 +0000"),
                              :userid => "w_awh9rd167wx5",
                              :ext_userid => "4310",
                              :event => :left
                            }
                          ]
                      },
                    "w_uhcrcgoenwub" =>
                      {
                        :joins =>
                          [
                            { :timestamp => Time.parse("2020-11-16 17:29:43 +0000"),
                              :userid => "w_uhcrcgoenwub",
                              :ext_userid => "4310",
                              :event => :join
                            }
                          ],
                        :lefts =>
                          [
                            { :timestamp => Time.parse("2020-11-16 17:30:22 +0000"),
                              :userid => "w_uhcrcgoenwub",
                              :ext_userid => "4310",
                              :event => :left
                            }
                          ]
                      },
                    "w_scp19cxkjwyo" =>
                      {
                        :joins =>
                          [
                            { :timestamp => Time.parse("2020-11-16 17:30:15 +0000"),
                              :userid => "w_scp19cxkjwyo",
                              :ext_userid => "4310",
                              :event => :join
                            },
                            { :timestamp => Time.parse("2020-11-16 18:08:14 +0000"),
                              :userid => "w_scp19cxkjwyo",
                              :ext_userid => "4310",
                              :event => :join
                            },
                            { :timestamp => Time.parse("2020-11-16 18:53:50 +0000"),
                              :userid => "w_scp19cxkjwyo",
                              :ext_userid => "4310",
                              :event => :join
                            }
                          ],
                        :lefts =>
                          [
                            { :timestamp => Time.parse("2020-11-16 18:04:12 +0000"),
                              :userid => "w_scp19cxkjwyo",
                              :ext_userid => "4310",
                              :event => :left
                            },
                            { :timestamp => Time.parse("2020-11-16 18:09:02 +0000"),
                              :userid => "w_scp19cxkjwyo",
                              :ext_userid => "4310",
                              :event => :left
                            },
                            { :timestamp => Time.parse("2020-11-16 19:21:12 +0000"),
                              :userid => "w_scp19cxkjwyo",
                              :ext_userid => "4310",
                              :event => :left
                            }
                          ]
                        },
                      "w_irmlt2pgxdnk" =>
                        {
                          :joins =>
                            [
                              { :timestamp => Time.parse("2020-11-16 18:02:34 +0000"),
                                :userid => "w_irmlt2pgxdnk",
                                :ext_userid => "4310",
                                :event => :join
                              }
                            ],
                          :lefts =>
                            [
                              { :timestamp => Time.parse("2020-11-16 18:56:42 +0000"),
                                :userid => "w_irmlt2pgxdnk",
                                :ext_userid => "4310",
                                :event => :left
                              }
                            ]
                          }
                    }


      finish = Time.parse("2020-11-16 19:23:12 +0000")

      expect(@sample.calculate_user_duration_based_on_userid(finish, sessions)).to eql(6735)
    end
  end
end
