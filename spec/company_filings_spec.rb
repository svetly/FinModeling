# company_filings_spec.rb

require 'spec_helper'

describe FinModeling::CompanyFilings  do
  before (:all) do
    @company = FinModeling::Company.find("aapl")
    @filings = FinModeling::CompanyFilings.new(@company.filings_since_date(Time.parse("2010-10-01")))
  end

  describe ".balance_sheet_analyses" do
    subject { @filings.balance_sheet_analyses }
    it { should be_a FinModeling::BalanceSheetAnalyses }
    it "should have one column per filing" do
      subject.num_value_columns.should == @filings.length
    end
  end

  describe ".cash_flow_statement_analyses" do
    subject { @filings.cash_flow_statement_analyses }
    it { should be_a FinModeling::CalculationSummary }
    it "should have one column per filing" do
      subject.num_value_columns.should == @filings.length
    end
  end

  describe ".income_statement_analyses" do
    subject { @filings.income_statement_analyses }
    it { should be_a FinModeling::IncomeStatementAnalyses }
    it "should have one column per filing" do
      subject.num_value_columns.should == @filings.length
    end
  end

  describe ".disclosures" do
    context "when a yearly disclosure is requested" do
      subject { @filings.disclosures(/Disclosure Provision For Income Taxes/, :yearly) }
      it { should be_a FinModeling::CalculationSummary }
      it "should have one column per 4 filings" do
        subject.num_value_columns.should be_within(2).of((@filings.length/4).floor)
      end
    end
    context "when a quarterly disclosure is requested" do
      subject { @filings.disclosures(/Disclosure Components Of Total Comprehensive I/, :quarterly) }
      it { should be_a FinModeling::CalculationSummary }
      it "should have one column per filing" do
        subject.num_value_columns.should be_within(3).of(@filings.length)
      end
    end
    context "when no period modifier is given (and the disclosure is yearly)" do
      subject { @filings.disclosures(/Disclosure Components Of Gross And Net Intangible Asset Balances/) }
      it { should be_a FinModeling::CalculationSummary }
      it "should have one column per 4 filings" do
        subject.num_value_columns.should be_within(2).of((@filings.length/4).floor)
      end
    end
  end

  describe ".choose_forecasting_policy" do
    context "when one or two filings" do
      let(:filings) { FinModeling::CompanyFilings.new(@filings.last(2)) }
      subject { filings.choose_forecasting_policy }

      it { should be_a FinModeling::GenericForecastingPolicy }
    end
    context "when two or more filings" do
      let(:filings) { FinModeling::CompanyFilings.new(@filings.last(3)) }
      subject { filings.choose_forecasting_policy }
      it { should be_a FinModeling::ConstantForecastingPolicy }

      let(:isa) { filings.income_statement_analyses }

      its(:revenue_growth) { should be_within(0.01).of(isa.revenue_growth_row.valid_vals.mean) }
      its(:sales_pm)       { should be_within(0.01).of(isa.operating_pm_row.valid_vals.mean) } # FIXME: name mismatch
      its(:sales_over_noa) { should be_within(0.01).of(isa.sales_over_noa_row.valid_vals.mean) } 
      its(:fi_over_nfa)    { should be_within(0.01).of(isa.fi_over_nfa_row.valid_vals.mean) }
    end
  end

  describe ".forecasts" do
    let(:policy) { @filings.choose_forecasting_policy }
    let(:num_quarters) { 3 }
    subject { @filings.forecasts(policy, num_quarters) }
    it { should be_a FinModeling::Forecasts }
    its(:reformulated_income_statements) { should have(num_quarters).items }
    its(:reformulated_balance_sheets)    { should have(num_quarters).items }
  end
end
