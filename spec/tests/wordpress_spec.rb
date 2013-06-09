require 'spec_helper'

describe WordPress do

  subject do
    $wp
  end

  context "#new_post" do

    subject do
      $wp.new_post({ :post_title => "Inital Post Title", :post_name => 'inital-post-title' })
    end

    its :class do
      should be WordPress::Post
    end

  end

  context "#query" do

    it "does query by :post_type" do
      subject.query( :post_type => 'post' ).count.should == 1
    end

    it "does query by :page_id" do
      subject.query( :page_id => 2 ).count.should == 1
    end

    it "does query by :pagename" do
      subject.query( :pagename => 'sample-page' ).count.should == 1
    end

    it "does query by :p" do
      subject.query( :p => 1 ).count.should == 1
    end

    it "does query by :post__in" do
      subject.query( :post__in => [1] ).count.should == 1
    end

    it "does query by :post__not_in" do
      subject.query( :post__not_in => [1] ).count.should == 0
    end

    context "meta queries" do

      before :each do
        # Build some metaquery test data.

      end

    end

  end

end
