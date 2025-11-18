# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::PaginationHelper, type: :helper do
  let(:collection) { double("Collection") }
  
  describe "#observ_pagination" do
    context "when collection is not paginated" do
      it "returns nil" do
        allow(collection).to receive(:respond_to?).with(:current_page).and_return(false)
        expect(helper.observ_pagination(collection)).to be_nil
      end
    end
    
    context "when collection is paginated" do
      before do
        allow(collection).to receive(:respond_to?).with(:current_page).and_return(true)
        allow(collection).to receive(:total_count).and_return(100)
        allow(collection).to receive(:offset_value).and_return(0)
        allow(collection).to receive(:limit_value).and_return(25)
        allow(collection).to receive(:current_page).and_return(1)
        allow(helper).to receive(:paginate).and_return("<pagination links>")
      end
      
      it "returns pagination wrapper" do
        result = helper.observ_pagination(collection)
        expect(result).to include('observ-pagination')
      end
      
      it "includes pagination info" do
        result = helper.observ_pagination(collection)
        expect(result).to include('Showing 1-25 of 100')
      end
      
      it "includes pagination links" do
        result = helper.observ_pagination(collection)
        expect(result).to include('observ-pagination__links')
      end
    end
    
    context "when collection is empty" do
      before do
        allow(collection).to receive(:respond_to?).with(:current_page).and_return(true)
        allow(collection).to receive(:total_count).and_return(0)
        allow(collection).to receive(:offset_value).and_return(0)
        allow(collection).to receive(:limit_value).and_return(25)
        allow(helper).to receive(:paginate).and_return("")
      end
      
      it "does not show pagination info" do
        result = helper.observ_pagination(collection)
        expect(result).not_to include('Showing')
      end
    end
    
    context "when on second page" do
      before do
        allow(collection).to receive(:respond_to?).with(:current_page).and_return(true)
        allow(collection).to receive(:total_count).and_return(100)
        allow(collection).to receive(:offset_value).and_return(25)
        allow(collection).to receive(:limit_value).and_return(25)
        allow(collection).to receive(:current_page).and_return(2)
        allow(helper).to receive(:paginate).and_return("<pagination links>")
      end
      
      it "shows correct range" do
        result = helper.observ_pagination(collection)
        expect(result).to include('Showing 26-50 of 100')
      end
    end
    
    context "when on last partial page" do
      before do
        allow(collection).to receive(:respond_to?).with(:current_page).and_return(true)
        allow(collection).to receive(:total_count).and_return(78)
        allow(collection).to receive(:offset_value).and_return(75)
        allow(collection).to receive(:limit_value).and_return(25)
        allow(collection).to receive(:current_page).and_return(4)
        allow(helper).to receive(:paginate).and_return("<pagination links>")
      end
      
      it "shows correct range for partial page" do
        result = helper.observ_pagination(collection)
        expect(result).to include('Showing 76-78 of 78')
      end
    end
  end
end
