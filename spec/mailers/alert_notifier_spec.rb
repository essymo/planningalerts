require 'spec_helper'

describe AlertNotifier do
  before :each do
    @alert = Alert.create!(:email => "matthew@openaustralia.org", :address => "24 Bruce Rd, Glenbrook NSW 2773",
      :lat => 1.0, :lng => 2.0, :radius_meters => 800)
    @alert.stub!(:confirm_id).and_return("abcdef")
    @original_emails_sent = Stat.emails_sent
    @original_applications_sent = Stat.applications_sent
    @a1 = mock_model(Application, :address => "Foo Street, Bar", :council_reference => "a1", :description => "Knock something down", :id => 1)
    @a2 = mock_model(Application, :address => "Bar Street, Foo", :council_reference => "a2", :description => "Put something up", :id => 2)
    @a3 = mock_model(Application, :address => "2 Foo Parade, Glenbrook NSW 2773", :id => 3)
    @c1 = mock_model(Comment, :text => "I think this is a great idea", :name => "Matthew Landauer", :application => @a3, :id => 1)
  end

  describe "when sending a planning alert with one new comment" do
    let(:email) { AlertNotifier.alert(@alert, [], [@c1])}

    it "should use the singular in the comment line" do
      email.subject.should == "1 new comment on planning applications near #{@alert.address}"
    end
  end

  describe "when sending a planning alert with two new comments" do
    let(:email) { AlertNotifier.alert(@alert, [], [@c1, @c2])}

    it "should use the plural in the comment line" do
      email.subject.should == "2 new comments on planning applications near #{@alert.address}"
    end
  end

  describe "when send a planning alert with one new comment and two new planning applications" do
    let(:email) { AlertNotifier.alert(@alert, [@a1, @a2], [@c1])}

    it "should tell you about both in the comment line" do
      email.subject.should == "1 new comment and 2 new planning applications near #{@alert.address}"
    end
    
    it "should nicely format (in text) a list of multiple planning applications" do
      get_message_part(email, /plain/).should == Rails.root.join("spec/mailers/regression/email2.txt").read
    end
  end

  describe "when sending a planning alert with one new planning application" do
    before :each do
      @email = AlertNotifier.alert(@alert, [@a1])
    end

    it "should use the singular (application) in the subject line" do
      @email.subject.should == "1 new planning application near #{@alert.address}"
    end
  end
  
  describe "when sending a planning alert with two new planning applications" do
    before :each do
      @email = AlertNotifier.alert(@alert, [@a1, @a2])
    end
    
    it "should be sent to the user's email address" do
      @email.to.should == [@alert.email]
    end
    
    it "should be from the main planningalerts email address" do
      @email.from.should == ["contact@planningalerts.org.au"]
      #@email.from_addrs.first.name.should == "PlanningAlerts.org.au"
    end
    
    it "should have a sensible subject line" do
      @email.subject.should == "2 new planning applications near #{@alert.address}"
    end
    
    it "should update the statistics" do
      Stat.emails_sent.should == @original_emails_sent + 1
      Stat.applications_sent.should == @original_applications_sent + 2
    end
    
    it "should update last_sent to the current time" do
      (Time.now - @alert.last_sent).abs.should < 1
    end
    
    it "should be a multipart email" do
      @email.body.parts.length.should eq(2)
    end

    context "Text email" do
      it "should nicely format a list of multiple planning applications" do
        get_message_part(@email, /plain/).should == Rails.root.join("spec/mailers/regression/email1.txt").read
      end
    end

    context "HTML emails" do
      before :each do
        @html_body = get_message_part(@email, /html/)
      end

      it 'should contain links to the applications' do
        contains_link(@html_body, "http://dev.planningalerts.org.au/applications/1?utm_medium=email&utm_source=alerts", "Foo Street, Bar")
        contains_link(@html_body, "http://dev.planningalerts.org.au/applications/2?utm_medium=email&utm_source=alerts", "Bar Street, Foo")
      end

      it 'should contain application descriptions' do
        @html_body.should contain "Knock something down"
        @html_body.should contain "Put something up"
      end

      it "should have a specific layout" do
        @html_body.should == Rails.root.join("spec/mailers/regression/email1.html").read
      end
    end

    def contains_link(html, url, text)
      html.should match /<a href="#{url.gsub(/\//, '\/').gsub(/&/, '&amp;').gsub(/\?/, '\?')}"[^>]*>#{text}<\/a>/
    end
  end

  def get_message_part (mail, content_type)
    mail.body.parts.find { |p| p.content_type.match content_type }.body.raw_source
  end
end
