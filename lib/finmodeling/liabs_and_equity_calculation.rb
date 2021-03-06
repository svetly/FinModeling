module FinModeling
  class LiabsAndEquityCalculation < CompanyFilingCalculation
    include CanCacheClassifications
    include CanCacheSummaries
    include CanClassifyRows

    BASE_FILENAME = File.join(FinModeling::BASE_PATH, "summaries/liabs_and_equity_")

    ALL_STATES  =           [ :ol, :fl, :cse, :mi ]
    NEXT_STATES = { nil  => [ :ol, :fl, :cse, :mi ],
                    :ol  => [ :ol, :fl, :cse, :mi ],  # operating liabilities
                    :fl  => [ :ol, :fl, :cse, :mi ],  # financial liabilities
                    :cse => [ :ol, :fl, :cse, :mi ],  # common shareholder equity
                    :mi  => [      :fl, :cse, :mi ] } # minority interest

    def summary(args)
      summary_cache_key = args[:period].to_pretty_s
      summary = lookup_cached_summary(summary_cache_key)
      return summary if !summary.nil?

      mapping = Xbrlware::ValueMapping.new
      mapping.policy[:debit] = :flip

      summary = super(:period => args[:period], :mapping => mapping) # FIXME: flip_total should == true!
      if !lookup_cached_classifications(BASE_FILENAME, summary.rows)
        lookahead = [4, summary.rows.length-1].min
        classify_rows(ALL_STATES, NEXT_STATES, summary.rows, FinModeling::LiabsAndEquityItem, lookahead)
        save_cached_classifications(BASE_FILENAME, summary.rows)
      end

      save_cached_summary(summary_cache_key, summary)

      return summary
    end

    def has_equity_item
      @has_equity_item ||= leaf_items.any? do |leaf|
        leaf.name.downcase.matches_regexes?([/equity/, /stock/])
      end
    end

  end
end
